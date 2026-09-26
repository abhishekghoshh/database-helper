# PostgreSQL Write Path

## Overview

INSERT, UPDATE, and DELETE all funnel through one pipeline: buffer pin → tuple write → index maintenance → WAL → commit flush → lazy page writeback. UPDATE is delete+insert with version metadata; everything amplifies through indexes, WAL, and future VACUUM. This file traces each statement type and explains why write-heavy workloads cost what they cost.

See also:

- [MVCC Internals](./mvcc-internals.md)
- [WAL: Write-Ahead Logging](./wal.md)
- [VACUUM Internals](./vacuum-internals.md)
- [Index Internals](./index-internals.md)
- [Checkpoints and Background Writer](./checkpoints-background-writer.md)
- [Why PostgreSQL Can Struggle With Write-Heavy Workloads](./why-postgres-struggles-with-writes.md)

## Why This Matters

Write throughput is bounded by WAL fsync rate, index maintenance, checkpoint smoothness, and vacuum capacity — in that order on most systems. Tuning writes without this pipeline means guessing which bound you're hitting.

## What Happens During INSERT / Execution / Heap Creation / Buffers / WAL / Commit

```mermaid
flowchart LR
    Exec[Executor] --> Pin[Pin target page via FSM]
    Pin --> Tuple[Write tuple: xmin=self, ctid]
    Tuple --> Idx[Insert index entries]
    Idx --> WAL[WAL records]
    WAL --> Flush[Commit flush]
    Flush --> Ack[ACK; pages stay dirty]
```

1. FSM picks a page with space (or extends the relation under extension lock).
2. Tuple written with `xmin` = own XID; indexes get one entry each (non-HOT by definition for inserts).
3. WAL records for heap + each index page; commit record; flush per `synchronous_commit`.
4. Dirty pages remain in shared buffers — checkpointer/bgwriter handles persistence later.

`COPY` and multi-row `INSERT` batch steps 1–3, amortizing WAL-insert locks and fsyncs — the entire basis of bulk-load performance.

## What Happens During UPDATE / Delete+Insert / HOT

UPDATE = mark old (`xmax` = self) + write new (`xmin` = self, chained `ctid`) + maintain indexes unless HOT-eligible (same page, no indexed-column change). Non-HOT updates pay: heap write × 2 versions' WAL + one index entry per index + future vacuum of the old version. See [MVCC Internals](./mvcc-internals.md) for the version mechanics.

## What Happens During DELETE / Dead Tuples / WAL

DELETE sets `xmax` and writes WAL for the header change plus index-entry removals (deferred via index cleanup at VACUUM for most AMs — indexes accumulate dead entries until vacuumed, which is index bloat's origin).

## Full-Page Writes / Checkpoint Interaction / Group Commit

- First page-touch after a checkpoint embeds the full 8 KB image in WAL (torn-page defense).
- Checkpoints bound recovery time but *cause* FPI amplification — frequent checkpoints = more WAL.
- Concurrent committers share fsyncs (group commit); commit latency tracks the slowest fsync in the batch.

## Write/ WAL / Index Amplification / Why UPDATE/DELETE Degrade

One logical UPDATE with 5 indexes ≈ heap old + heap new + 5 index entries + WAL for all + later vacuum + later index cleanup. Rule of thumb: **write cost scales with index count, row width (TOAST), and FPI rate** — not just row count. Excessive UPDATE/DELETE degrades reads too: bloat lengthens scans, dead index entries slow lookups, vacuum/autovacuum consume the I/O budget.

## Bottlenecks: WAL / IOPS / CPU / Locks / Checkpoints / Autovacuum / Bloat

| Bound | Signal | Fix direction |
|---|---|---|
| WAL fsync | `pg_stat_wal` bytes high, commit latency = fsync latency | faster `pg_wal` device, batching, `synchronous_commit=off` for non-critical |
| IOPS | data-device await high, bgwriter/checkpointer saturated | spread tablespaces, tune checkpoints, reduce indexes |
| CPU | executor + WAL compression + vacuum workers saturated | fewer indexes/expressions, parallel maintenance windows |
| Lock contention | `pg_locks` queues on hot rows/pages, extension-lock waits | partition hot tables, smaller transactions, sequence gaps |
| Checkpoint pressure | latency spikes aligned with checkpoints | raise `max_wal_size`, `checkpoint_completion_target` → 0.9 |
| Autovacuum pressure | `n_dead_tup` climbing, VM never set | thresholds, cost limits, workers, kill xmin holders |
| Bloat | scans slower at same row count | fillfactor, HOT-friendly updates, partitioning, repack |

## What Actually Happens Internally?

```sql
UPDATE users SET name = 'John' WHERE id = 10;
```

1. Backend parses, plans (likely PK index scan), pins the heap page.
2. Visibility check passes; HOT eligibility evaluated (is `name` indexed? same-page room?).
3. New version written, old marked, indexes touched iff non-HOT.
4. WAL (heap + index deltas, maybe FPI) generated; commit flushed.
5. Old version lingers until snapshots release it and VACUUM reclaims it.

## Hands-on Experiment

```sql
CREATE TABLE w(id serial primary key, v int, pad text);
INSERT INTO w(v,pad) SELECT 1, 'x' FROM generate_series(1,10000);
SELECT pg_current_wal_lsn() AS lsn0 \gdesc
UPDATE w SET v = 2;  -- non-HOT? v unindexed... make it indexed to compare
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), (SELECT lsn0)));
-- add index on v, repeat, compare WAL bytes + n_dead_tup + n_tup_hot_upd
```

## Troubleshooting

### Symptom: write throughput collapses after months of growth

**Diagnose:** `n_dead_tup` trend, index sizes vs table (`pg_indexes_size`), checkpoint frequency (`log_checkpoints`), `pg_stat_wal` rate. **Fix order:** vacuum catch-up → drop redundant indexes → checkpoint smoothing → partition/bulk-load redesign.

## Interview Questions

### Intermediate

- Why is UPDATE more expensive than INSERT even for one row? — Old-version marking + new version + (usually) full index maintenance + guaranteed future vacuum work.
- Where does group commit help and where doesn't it? — Helps fsync-bound small commits; irrelevant when bound by row locks or CPU.

### Advanced

- How do indexes amplify WAL? — Each index entry is its own WAL-logged page change; wide/duplicate-heavy indexes multiply bytes per logical write.
- Why do checkpoints make writes *spikier* rather than smoother when mistuned? — Short `checkpoint_timeout` + small `max_wal_size` force bursty full-speed flushes; `completion_target` spreads them.

## Key Takeaways

- Every write pays four times: heap, indexes, WAL now, VACUUM later.
- HOT updates and fillfactor are the cheapest write optimization available — design for them.
- Find the bound (WAL/IOPS/CPU/locks/vacuum) before tuning; each has different signals.
