# PostgreSQL Internals Projects

## Overview

Thirty hands-on labs that turn this series from reading into muscle memory. Each project lists goal → setup → steps → expected observations → explanation links. Work in order; later labs assume earlier tooling (psql, EXPLAIN, slot/progress views).

## Labs

### Build and boot

1. **Build from source** (`--enable-debug --enable-cassert`, initdb with checksums): goal — runnable dev cluster; observe configure checks, `PGDATA` layout; links [Source](./postgresql-source-code-architecture.md), [Storage](./postgresql-storage-architecture.md).
2. **Trace client→backend** (`log_connections`, `pg_backend_pid()`, `ps -o pid,comm`): goal — see fork-per-connection; observe postmaster vs backend PIDs.
3. **Inspect shared memory** (`pg_buffercache`, `pg_shmem_allocations`): goal — buffers/locks/clog as countable rows.
4. **Inspect data directory + relation files** (`pg_relation_filepath`, `ls base/`, `pg_controldata`): goal — OID→file mapping incl. forks/segments.

### Pages, tuples, MVCC, vacuum

5. **Pages/tuple headers** (`pageinspect`: `heap_page_items`, `bt_page_items`): goal — item pointers, infomasks, CTID chains.
6. **Observe `xmin`/`xmax`** across INSERT/UPDATE/DELETE + `SELECT xmin,xmax,ctid`.
7. **Concurrent MVCC**: two terminals, uncommitted UPDATE vs reader — snapshot visibility live ([MVCC](./mvcc-internals.md)).
8. **Dead tuples + VACUUM** (`n_dead_tup` before/after, `VACUUM VERBOSE` output reading).
9. **HOT updates** (`n_tup_hot_upd` ratio; indexed vs non-indexed column updates; fillfactor comparison).
10. **Bloat creation + analysis** (churn workload → `pgstattuple`/`pgstatindex` → repack/reindex compare).

### WAL, checkpoints, replication, wraparound

11. **WAL growth inspection** (`pg_current_wal_lsn` diffs per workload shape; FPI effect across CHECKPOINT).
12. **Trigger/observe checkpoints** (`log_checkpoints`, `CHECKPOINT`, bgwriter counters).
13. **PgBouncer + exhaustion sim** (transaction pooling; `cl_waiting`; storm without pooler in staging).
14. **Streaming replication + lag measurement** (sent/flush/replay gaps under load; conflict via long standby query).
15. **Logical replication + CDC pipeline** (publication → subscription; then slot → Debezium → Kafka topic).
16. **Wraparound sim** (advance `age(datfrozenxid)` on test DB with XID-burning workload; watch autovacuum-freeze escalation — staging only).

### Performance and operations

17. **Write vs read benchmarks** (pgbench custom scripts; COPY vs INSERT; batch sizes; `synchronous_commit` tiers with measured loss windows).
18. **`work_mem` spill lab** (`EXPLAIN ANALYZE` sort/hash across settings; `log_temp_files` sizes).
19. **Checkpoint configs A/B** (`max_wal_size`/`completion_target` vs p99 + replay-time estimate).
20. **Plan analysis** (`EXPLAIN (ANALYZE, BUFFERS)` on 5 production-shaped queries; estimate-vs-actual fixes via stats targets/extended stats).
21. **Monitoring dashboard** (exporter + panels for lag, bloat velocity, xmin age, pool wait, checkpoint freq, temp bytes).
22. **HA with operator** (CloudNativePG/Patroni in kind/k3d: failover, fencing, PITR restore drill).

Each lab's cleanup: drop test roles/slots/publications, reset altered GUCs (`ALTER SYSTEM RESET`, reload), remove test clusters.

## Interview Questions

Labs double as interview evidence: "show me HOT ratio improvement from fillfactor change" beats "I know what HOT is." Keep outputs (EXPLAIN plans, `VERBOSE` logs, dashboard screenshots) as portfolio artifacts.

## Key Takeaways

- Instrument-first labs (inspect before theorizing) build the mental models this series assumes.
- Every lab ends at a metric — if nothing was measured, the lab isn't done.
