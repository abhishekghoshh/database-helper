# Monitoring PostgreSQL Internals

## Overview

PostgreSQL exposes internals through cumulative statistics views (`pg_stat_*`), progress views (`pg_stat_progress_*`), lock/activity views, and `pg_stat_statements`. This file maps each signal to the subsystem it reveals and the incident it predicts.

See also:

- [PostgreSQL Logging and Debugging](./postgresql-logging-debugging.md)
- [VACUUM Internals](./vacuum-internals.md)
- [Replication Internals](./replication-internals.md)
- [Locks and Concurrency Internals](./locks-concurrency-internals.md)

## Why This Matters

Every troubleshooting section in this series bottoms out at queries below. Keep this file open during incidents.

## Statistics System / Activity / Database / Tables / Indexes / BgWriter / WAL / Replication / Slots / Progress / Locks / Statements

```sql
-- connections & current work
SELECT pid, usename, state, wait_event_type, wait_event, now()-query_start AS age, query
FROM pg_stat_activity ORDER BY query_start LIMIT 20;

-- cache efficiency (per-db since reset)
SELECT datname, blks_hit, blks_read,
       round(100.0*blks_hit/NULLIF(blks_hit+blks_read,0),1) AS hit_pct FROM pg_stat_database;

-- vacuum/analyze pressure + bloat proxy
SELECT relname, n_live_tup, n_dead_tup, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 10;

-- index usage (unused indexes = write tax)
SELECT indexrelname, idx_scan, idx_tup_read FROM pg_stat_user_indexes ORDER BY idx_scan LIMIT 10;

-- writer/checkpoint health
SELECT buffers_checkpoint, buffers_clean, buffers_backend FROM pg_stat_bgwriter;

-- WAL rate + slots retention
SELECT * FROM pg_stat_wal;
SELECT slot_name, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained
FROM pg_replication_slots;

-- replication lag anatomy
SELECT client_addr, state, pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS total_lag,
       sent_lsn, flush_lsn, replay_lsn FROM pg_stat_replication;

-- vacuum/index-build progress
SELECT * FROM pg_stat_progress_vacuum;
SELECT * FROM pg_stat_progress_create_index;

-- locks & blockers (pg_blocking_pids needs a pid)
SELECT pid, usename, pg_blocking_pids(pid) AS blocked_by, query FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;

-- top queries (needs pg_stat_statements)
SELECT query, calls, round(mean_exec_time::numeric,2) AS mean_ms,
       round((100*total_exec_time/sum(total_exec_time) OVER ())::numeric,1) AS pct
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;
```

## Connections / Queries / Blocking / Deadlocks / Hit Ratio / WAL Rate / Checkpoints / Autovacuum / Lag / Disk / Bloat

Alert thresholds that survive contact with production:

| Signal | Warn | Critical | Notes |
|---|---|---|---|
| Active backends / `max_connections` | 70% | 90% | plus `idle in transaction` count separately |
| Cache hit ratio (5-min window, OLTP) | < 99% | < 98% | use deltas, not cumulative since reset |
| `n_dead_tup` growth rate | vacuum can't hold steady | wraparound warnings in logs | trend, not absolute |
| Replication total lag | > 1 GB or replay delay SLO | slot retained > disk headroom | per-standby |
| Checkpoint freq | < 5 min on OLTP | < 1 min | raise `max_wal_size` |
| Temp bytes rate | sustained spill on new query | temp disk filling | `log_temp_files` + `pg_stat_database` |
| Oldest `backend_xmin` age | > 10 min | > 1 h | vacuum blocker hunt |

Stats reset semantics: most `pg_stat_*` counters are cumulative since reset (`pg_stat_reset()`); rates need two samples. `pg_stat_statements` needs `track_timing`, and `queryid` normalization to aggregate across literals.

## Hands-on Experiment

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT pg_stat_reset();
-- run workload; sample pg_stat_database twice, compute hit-ratio delta and WAL bytes/sec
SELECT datname, blks_hit, blks_read, xact_commit, xact_rollback, temp_bytes FROM pg_stat_database;
```

## Troubleshooting

### Symptom: dashboard shows 99.9% hit ratio but queries are slow

Cumulative-since-reset ratio hides recent eviction storms. **Fix:** windowed deltas (Prometheus `rate()` on `pg_stat_database_blks_*`), per-query `EXPLAIN (ANALYZE, BUFFERS)`.

## Interview Questions

### Intermediate

- `pg_stat_activity` vs `pg_locks` vs `pg_stat_progress_vacuum` — which answers what? — Activity: what each backend does/waits on. Locks: who holds/waits which lock. Progress: vacuum/index-build phase + heap blocks done/total.
- Why are cumulative counters misleading? — Resets, failovers, and ancient history dilute current behavior; always difference over windows.

## Key Takeaways

- Monitor rates and horizons (lag bytes, dead-tuple velocity, xmin age), not just point-in-time counters.
- `pg_stat_statements` + `auto_explain` + structured logs form the complete slow-query picture.
- Every alert needs its diagnostic query attached — this file is that attachment.
