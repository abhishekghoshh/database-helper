# VACUUM Internals

## Overview

VACUUM reclaims dead tuples MVCC leaves behind, freezes old XIDs against wraparound, updates planner statistics hooks, and maintains the visibility map and free-space map. Autovacuum schedules it. This file explains the phases, the throttles, and every way it falls behind.

See also:

- [MVCC Internals](./mvcc-internals.md)
- [PostgreSQL Write Path](./postgresql-write-path.md)
- [Why PostgreSQL Can Struggle With Write-Heavy Workloads](./why-postgres-struggles-with-writes.md)
- [Monitoring PostgreSQL Internals](./monitoring-postgres-internals.md)

## Why This Matters

VACUUM is the exhaust system of MVCC. When it lags: bloat, seq-scan slowdowns, transaction-ID emergencies, and eventually write shutdowns. Most "Postgres got slow over months" stories are vacuum stories.

## Why VACUUM Exists / MVCC Link / Dead-Tuple Cleanup

PostgreSQL cannot remove an old version at UPDATE/DELETE time because concurrent snapshots may still need it. Removal is only safe once *no* snapshot can see the version — a global property VACUUM computes from the oldest `xmin` horizon. So: writes create garbage asynchronously; VACUUM collects it asynchronously. There is no synchronous alternative that preserves lock-free reads.

## VACUUM vs DELETE / TRUNCATE / VACUUM FULL

| Operation | Removes rows? | Reclaims OS disk? | MVCC-safe async? |
|---|---|---|---|
| `DELETE` | marks dead (`xmax`) | no | creates the garbage |
| `VACUUM` | removes dead tuples, marks pages reusable | only truncated empty tail pages | yes, lazy |
| `VACUUM FULL` / `CLUSTER` | rewrites table file | yes (new file) | no — `ACCESS EXCLUSIVE` lock, heavy I/O |
| `TRUNCATE` | drops storage instantly | yes | DDL, immediate, minimal WAL |

## Lazy VACUUM Phases

`src/backend/access/heap/vacuumlazy.c` (`heap_vacuum_rel`):

1. **Heap scan + prune**: scan pages, HOT-prune chains, collect dead TIDs (bounded by `maintenance_work_mem`), note free space.
2. **Index cleanup** (`vacuumcleanup` per index AM): remove index entries pointing at dead TIDs. Repeat scan+cleanup passes if dead TIDs overflowed memory.
3. **Heap cleanup**: remove dead tuples, defragment within pages, update FSM.
4. **VM/FSM updates**: set all-visible/all-frozen bits, truncate empty tail pages (only unlocked tail, briefly needs stronger lock).
5. **Freeze + stats**: freeze eligible XIDs, update `relfrozenxid`, `pg_class` stats.

```mermaid
flowchart LR
    Scan[Heap scan + prune] --> Idx[Index cleanup]
    Idx --> Heap[Heap cleanup]
    Heap --> Maps[VM + FSM update]
    Maps --> Freeze[Freeze + stats]
```

## Page Pruning / HOT Pruning / Cost Throttling / Parallelism

- **Page pruning**: any backend touching a page can drop dead chain links using its own snapshot horizon — cheap, opportunistic.
- **HOT pruning**: subset of the above for HOT chains.
- **Cost-based throttling** (`vacuum_cost_delay`, `vacuum_cost_limit`): vacuum sleeps to cap I/O; autovacuum workers share `autovacuum_vacuum_cost_limit`. Raising limits is the first lever when vacuum can't keep up.
- **Parallelism** (v13+ `PARALLEL` option, leader + workers for index cleanup): speeds large-table vacuum at CPU cost.

## Freezing / Aggressive / Anti-Wraparound VACUUM

- Normal vacuum freezes tuples older than `vacuum_freeze_min_age`.
- **Aggressive** (`VACUUM (FREEZE)`) freezes more eagerly, setting all-frozen VM bits so future anti-wraparound scans can skip pages.
- **Anti-wraparound**: triggered when `relfrozenxid` age nears `autovacuum_freeze_max_age`; scans even "clean" pages lacking all-frozen bits. Emergency mode (`vacuum_freeze_table_age`) prioritizes freezing over cleanup.

## Autovacuum: Launcher, Workers, Thresholds

Launcher (`autovacuum.c`) wakes every `autovacuum_naptime`, computes per-table need:

```text
vacuum if: n_dead_tup > autovacuum_vacuum_threshold + autovacuum_vacuum_scale_factor × n_live_tup
analyze if: inserts/updates/deletes > autovacuum_analyze_threshold + autovacuum_analyze_scale_factor × n_live_tup
```

Defaults (`50 + 0.1 × size`) vacuum a 10 M-row table only after ~1 M dead tuples — far too lax for hot tables. Set per-table storage parameters:

```sql
ALTER TABLE hot_events SET (
  autovacuum_vacuum_scale_factor = 0.02,
  autovacuum_vacuum_threshold = 1000,
  autovacuum_vacuum_cost_delay = 0
);
```

Cap concurrency with `autovacuum_max_workers` (default 3) and `autovacuum_work_mem` so workers don't each grab full `maintenance_work_mem`.

## Why Autovacuum Falls Behind / Write-Heavy Interaction

```text
heavy UPDATE/DELETE → dead tuples faster than vacuum reclaims
  + cost-delay sleeps + too few workers + long-xmin horizon blocking removal
  → bloat → longer scans → more I/O → vacuum even slower → spiral
```

Break the spiral: raise cost limits, add workers, lower per-table thresholds, kill xmin-holders, consider partitioning/fillfactor/HOT-friendly schema (see [Why PostgreSQL Can Struggle With Write-Heavy Workloads](./why-postgres-struggles-with-writes.md)).

## When VACUUM Can't Reclaim Space / VACUUM FULL / REINDEX / Bloat

- Regular VACUUM only truncates empty pages at the physical end; interior holes stay reusable, file size unchanged.
- `VACUUM FULL`/`CLUSTER` rewrite the file (needs ~table-size free disk + `ACCESS EXCLUSIVE` lock). `pg_repack` does it online via triggers.
- `REINDEX (CONCURRENTLY)` rebuilds bloated indexes without blocking writes (v12+).
- Bloat detection: `pg_stat_user_tables.n_dead_tup`, `pgstattuple` extension (`pgstattuple()`, `pgstatindex()`), varia script `check_bloat`.

## What Actually Happens Internally?

`VACUUM (VERBOSE) orders`:

1. Compute OldestXmin horizon (backends, slots, prepared xacts, standby feedback).
2. Scan heap: prune chains, collect dead TIDs up to memory budget.
3. For each index: bulk-delete dead entries.
4. Sweep heap: remove tuples, compact pages, rebuild FSM entries.
5. Set VM bits, attempt tail truncation, freeze XIDs, update `pg_class` + `relfrozenxid`.

## Hands-on Experiment

```sql
CREATE TABLE v(id serial primary key, val text);
INSERT INTO v(val) SELECT 'x' FROM generate_series(1,100000);
UPDATE v SET val='y';  -- 100k dead tuples
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname='v';
VACUUM (VERBOSE) v;    -- watch pages removed, VM bits, FREEZE info
```

Then hold `BEGIN; SELECT * FROM v LIMIT 1;` open in another session, repeat the UPDATE, and watch VACUUM report "0 removable, N nonremovable" — the xmin horizon in action.

## Troubleshooting

### Symptom: `VACUUM` runs constantly, `n_dead_tup` never drops

**Diagnose:** `SELECT backend_xmin, pid, query FROM pg_stat_activity WHERE backend_xmin IS NOT NULL ORDER BY backend_xmin;` plus `SELECT * FROM pg_replication_slots WHERE NOT active;` and `SELECT * FROM pg_prepared_xacts;` **Fix:** terminate holders; `VACUUM (VERBOSE)` to confirm removable count rises.

### Symptom: `database must be vacuumed before N more transactions` warnings

Emergency anti-wraparound. **Fix:** immediate manual `VACUUM (FREEZE)` on flagged tables (raise `maintenance_work_mem`, disable cost delay for the run), then fix thresholds so autovacuum gets there first next time.

## Interview Questions

### Intermediate

- Why can't VACUUM return all freed space to the OS? — It compacts within pages and truncates only empty tail pages; interior holes become reusable free space (which is the point — reuse beats syscall churn).
- What do scale_factor/threshold defaults get wrong for hot tables? — Absolute dead-tuple counts before triggering scale with table size; a 1 B-row table accumulates 100 M dead tuples before default autovacuum fires.

### Advanced

- What is cost-based throttling protecting, and when do you disable it? — Foreground I/O from vacuum storms; disable/lower delay for the hot tables or during catch-up windows.
- VACUUM FULL vs pg_repack vs CLUSTER? — Full: rewrite + exclusive lock, simplest. CLUSTER: rewrite in index order (also clusters heap). pg_repack: online rewrite via triggers, needs free space + extension.

## Key Takeaways

- VACUUM completes MVCC: without it, versions accumulate until wraparound stops the world.
- Thresholds, cost limits, worker counts, and xmin horizons are the four knobs — tune in that order.
- Bloat metrics (`n_dead_tup`, `pgstattuple`) belong on every PostgreSQL dashboard.
