# Why PostgreSQL Can Struggle With Write-Heavy Workloads

## Overview

Every PostgreSQL write pays MVCC versioning, per-index maintenance, WAL (with FPI), future vacuum, and replica replay. At high UPDATE/DELETE rates these multipliers compound into vacuum lag, bloat, checkpoint pressure, and WAL saturation. This file names each multiplier, shows the spiral, and gives the escape routes.

See also:

- [PostgreSQL Write Path](./postgresql-write-path.md)
- [MVCC Internals](./mvcc-internals.md)
- [VACUUM Internals](./vacuum-internals.md)
- [PostgreSQL Scaling](./postgresql-scaling.md)
- [Partitioning Internals](./partitioning-internals.md)

## Why This Matters

Write-heavy incidents look like "many small problems at once" — they are one problem (amplification > reclaim capacity) seen through five dashboards. Fix the imbalance, not the dashboards.

## The Multiplier Stack

```text
1 logical UPDATE
  → heap old-mark + heap new (2 page touches)
  → N index entries (N = index count, unless HOT)
  → WAL for all + FPI on first touch per checkpoint
  → replica replay of all
  → future VACUUM + index cleanup
  → bloat if vacuum lags → longer scans → more I/O → slower vacuum
```

Per-subtopic mechanics:

- **Dead tuples / UPDATE-new-versions / DELETE garbage**: update rate = garbage rate; reclaim rate = vacuum throughput minus xmin-blocked pages.
- **VACUUM overhead + autovacuum pressure**: cost-delay sleeps + 3 default workers vs millions of dead tuples/hour — arithmetic, not mystery.
- **WAL generation + FPI**: first-touch pages per checkpoint double/triple WAL bytes; `wal_compression` trades CPU for bytes.
- **Index maintenance + write amplification**: each index adds entries, WAL, and cleanup; compounding per hot table.
- **Page splits** (B-tree leaf splits on random inserts): half-empty pages + parent updates + WAL, worst with UUID-random PKs (use v7/time-ordered or bigint).
- **Checkpoint pressure**: WAL volume forces frequent checkpoints → flush storms → p99 spikes → app retries → more writes.
- **Random I/O**: non-HOT updates scatter heap + index writes; SSDs absorb, HDDs collapse.
- **Long transactions + slots blocking cleanup**: turn reclaimable garbage into pinned garbage — see [MVCC](./mvcc-internals.md).
- **Lock contention**: hot-row updates serialize on row locks; sequence/extension locks on append-only.

## The Spiral

```text
writes ↑ → dead tuples ↑ → vacuum falls behind → bloat ↑
  → scans/indexes slower → I/O ↑ → vacuum slower still
  → WAL ↑ → checkpoints ↑ → latency spikes → retries → writes ↑
```

## Escape Routes

| Lever | Effect | Cost |
|---|---|---|
| HOT-friendly schema (`fillfactor` 70–85, no indexed churn columns) | indexes untouched, less WAL | reserve space, design discipline |
| Fewer/narrower indexes on hot tables | linear write-cost cut | slower some reads (measure) |
| Partitioning + drop-retention | bounds vacuum/index size | routing + count overhead |
| Bulk paths (`COPY`, multi-row INSERT, batch UPDATE with keyset) | amortizes WAL/fsync/locks | app changes |
| `UNLOGGED` tables (ephemeral data) | skips WAL entirely | lost on crash; no replication |
| `synchronous_commit = off/local` for non-critical streams | removes fsync from path | bounded loss window |
| Fillfactor + autovacuum per-table tuning | keeps reclaim ahead | monitoring + iteration |
| Scale-out (read replicas offload, sharding/Citus for writes) | raises ceiling | complexity — see [Scaling](./postgresql-scaling.md) |

`COPY` vs `INSERT`: single snapshot, batched WAL, no per-row parse/plan — 10–100× for loads. Batch writes in explicit transactions with `SET LOCAL synchronous_commit OFF` where durability tiers allow.

## Vertical vs Horizontal / Write Scaling Limits

Single-node writes scale with CPU (parallel workers don't parallelize one OLTP write), WAL-device fsync rate, and vacuum capacity — all sublinear past ~tens of thousands of small writes/sec with indexes. Past that: partition, shard (Citus), or split streams (hot path to purpose-built store, truth in PG).

## Hands-on Experiment

```sql
CREATE TABLE w(id serial primary key, v int, pad text DEFAULT 'x');
INSERT INTO w(v) SELECT 1 FROM generate_series(1,100000);
SELECT pg_current_wal_lsn() AS a \gdesc  -- save LSN
UPDATE w SET v = 2;
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), (SELECT a)));
SELECT n_tup_upd, n_tup_hot_upd FROM pg_stat_user_tables WHERE relname='w';  -- HOT ratio
-- add index on v, repeat: WAL bytes and hot ratio change visibly
```

## Troubleshooting

### Symptom: inserts fine, updates degrade over the day, vacuum always behind

HOT ratio near zero (indexed churn column or fillfactor 100) + default autovacuum thresholds. **Fix:** lower fillfactor + rewrite, drop/cover churn index, per-table vacuum tuning, then re-measure HOT ratio — it should climb past 80%.

## Interview Questions

### Intermediate

- Why does adding an index slow writes more than linearly at scale? — Per-index entries + WAL + cleanup + vacuum + checkpoint pressure compound; the 6th index joins an already-loaded pipeline.
- `COPY` vs batched `INSERT`? — COPY skips per-row parse/plan/executor overhead and batches WAL; multi-row INSERT is close but still plans per statement.

### Advanced

- When do UNLOGGED tables lose data, exactly? — Crash or unclean shutdown truncates them at recovery; also excluded from replication/backups of standby promotion. Session data, scratch ETL — never ledger.
- Why do random-UUID PKs hurt write-heavy tables specifically? — Random inserts split leaves everywhere (half-empty pages, WAL, fragmentation) vs append-only rightmost growth.

## Key Takeaways

- Write cost = heap × (1 + indexes − HOT savings) × WAL(FPI) × vacuum-later × replicas.
- HOT ratio and dead-tuple velocity are the two numbers that predict write incidents.
- Bulk paths, fillfactor, index discipline, and partitioning — in that order — before sharding.
