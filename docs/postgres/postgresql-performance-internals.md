# PostgreSQL Performance Internals

## Overview

PostgreSQL performance decomposes by bound: CPU, memory, I/O, WAL, locks, connections, vacuum, checkpoints, planning. This file gives the bound-finding method, the cache story (shared buffers vs OS cache), amplification accounting, and NUMA/hardware notes.

See also:

- [Query Execution Internals](./query-execution-internals.md)
- [PostgreSQL Memory Architecture](./postgresql-memory-architecture.md)
- [Why PostgreSQL Can Struggle With Write-Heavy Workloads](./why-postgres-struggles-with-writes.md)
- [Monitoring PostgreSQL Internals](./monitoring-postgres-internals.md)

## Why This Matters

Tuning the wrong bound wastes quarters: adding RAM to a lock-bound system, indexes to a WAL-bound one. Identify the bound first with wait events + resource signals, then tune.

## Performance Model / Bound Taxonomy

```text
pg_stat_activity.wait_event_type: CPU (null wait, high usage) | IO (DataFileRead) |
  Lock (transactionid, relation) | LWLock (WALInsert, buffer_content) |
  Client (idle = pooling problem) | IPC (parallel queues)
+ host: iostat await, vmstat, pg_stat_wal bytes/s, checkpoint cadence
```

| Bound | Primary signal | First levers |
|---|---|---|
| CPU | `EXPLAIN ANALYZE` execution time, JIT/expression heavy | fewer rows earlier (prune/pushdown), JIT for analytics, scale cores |
| Memory | temp spill, eviction, OOM | `work_mem` per role, partitioning, replica analytics |
| I/O | `DataFileRead` waits, low hit ratio windows | indexes, covering, OS-cache sizing, faster devices |
| WAL | commit latency = fsync, `wal_bytes` high | batching, `synchronous_commit` tiers, fewer indexes |
| Lock | `Lock` waits, queue depth | shorter txns, `lock_timeout`, retry logic |
| Connection | `ClientRead` idle mass, fork storms | PgBouncer transaction pooling |
| Autovacuum/vacuum | dead-tuple velocity > reclaim | thresholds, workers, HOT design |
| Checkpoint | spikes on `log_checkpoints` lines | `max_wal_size`, completion target, WAL device |
| Planning | parse/plan ms on hot path | prepared statements, `plan_cache_mode`, simpler dynamic SQL |

## Cache Behavior / OS Page Cache / Buffers / Concurrency / Amplification / Latency / NUMA

- **Two-level cache**: shared buffers (precise, WAL-aware) + OS page cache (large, dumb). Size shared buffers to the hot working set (often 25% RAM), leave the rest to the OS. `effective_cache_size` tells the planner the sum.
- **Amplification accounting** (per logical write): heap + per-index entries + FPI + WAL + vacuum later + replica replay. Measure with `pg_wal_lsn_diff` per workload change — index additions included.
- **I/O concurrency**: `effective_io_concurrency` (async prefetch depth for bitmap/parallel scans) matters on SSD/NVMe; `maintenance_io_concurrency` for vacuum/index builds.
- **NUMA**: multi-socket hosts suffer cross-node memory latency; pin PostgreSQL + pooler with `numactl`/cgroups or accept noisy p99. Large `shared_buffers` interleaved across nodes beats single-node saturation.

## Hands-on Experiment

```sql
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) SELECT ...;  -- hit/read split
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0'));  -- baseline
-- add one index, rerun workload, diff WAL bytes: the index's amplification price
```

## Troubleshooting

### Symptom: CPU-bound with low I/O wait but high query latency

Expression/projection heavy or lock-spinning. **Diagnose:** `EXPLAIN ANALYZE` actual time in nodes vs I/O waits; `perf top` for executor/JIT vs `LWLock` spin. **Fix:** reduce row width early (projection pushdown), JIT for analytics, fix spinlock contention (extension/sequence hotspot).

## Interview Questions

### Advanced

- Why can more RAM not fix an I/O-bound query? — If the plan scans dead tuples/bloat or can't use an index, extra cache just caches garbage faster; fix the plan/vacuum first.
- How do you prove which bound you're on? — Wait-event distribution + the resource counter that saturates with load (IOPS await, WAL bytes/s, lock queue depth, active-backend CPU).

## Key Takeaways

- Name the bound with wait events + rates before touching knobs.
- Amplification (indexes × WAL × vacuum × replicas) is the write-side budget — measure per change.
- Caches are two-level; plans, vacuum, and checkpoints decide what the cache holds.
