# PostgreSQL Architecture Case Studies

## Overview

Seventeen design scenarios in a uniform format — context → key decisions → mechanics → failure handling. Each links the deep-dive files; together they convert internals knowledge into architecture judgment.

## How to Use This File

Read the scenario matching your problem, follow its links for mechanics, then check [Failure Scenarios](./postgresql-failure-scenarios.md) for what breaks. Scenarios assume the [README roadmap](./README.md) background.

## Throughput and Shape

### High-throughput system

10k TPS mixed OLTP: PgBouncer txn pooling (pool ~50, clients 5k), primary on NVMe with isolated WAL device, sync replica for durability, `synchronous_commit = on` for money paths / `off` for telemetry, HOT-friendly fillfactor 80, per-table autovacuum, `log_checkpoints` + pool-wait dashboards. Bound watched: WAL fsync latency, then vacuum velocity.

### Write-heavy system

Ingest 100k rows/s: partition by time (daily), drop-retention (no DELETE), `COPY`/batch loads, minimal indexes on hot partitions (2–3), BRIN where ordered, `UNLOGGED` staging, `max_wal_size` large + completion 0.9, 6+ autovacuum workers with per-partition thresholds. Exit: Citus distribution on tenant key when single-writer WAL saturates. See [write-heavy](./why-postgres-struggles-with-writes.md).

### Read-heavy system

90/10 read mix: 2–3 async replicas + read/write splitting (session-critical reads to primary), covering indexes + materialized summaries (`REFRESH CONCURRENTLY`), Redis for µs hot keys, `effective_cache_size` honest, replica lag SLO with route-downgrade on breach.

### Millions of connections / with PgBouncer

10k app connections: PgBouncer tier (2+ instances, txn mode, `max_client_conn` 10k, `default_pool_size` ~100), `max_connections` stays 200, prepared-statement handling (`prepareThreshold=0` or session pools for the few that need them), per-service pool stats + `cl_waiting` alerts.

### Read replicas / HA / Multi-region

HA: Patroni + etcd across 3 AZs, sync replica (`FIRST 1`), fencing tested, `pg_rewind` runbook. Multi-region: async cascade per region (local reads), writes to home region (conflict-free), or BDR multi-primary only with resolver-owned tables. RPO/RTO stated per region, drilled quarterly.

## Data Scale

### Large tables / billions of rows

Time-partitioned (monthly), local indexes incl. partition key, BRIN for ordered scans, detach-based archival to object storage, `pg_repack` windows for rewrites, ANALYZE-per-partition in load jobs, extended statistics on correlated dims. Query contract: every hot query prunes.

### High-ingestion / event-driven / CDC source

Append-only event tables (no updates, ever) + logical decoding → Kafka (Debezium) → sinks; outbox for transactional events; slot-lag alerts with drop/re-snapshot runbook; consumer backpressure wired to producer throttling.

### Job queue / Kubernetes / Backup-DR / Observability

Queue: `SKIP LOCKED` table + advisory-lock single-flight + archive-completed partitions; exit to broker past ~10k jobs/s. K8s: CloudNativePG StatefulSets, separate storage classes, object-store backups, pooler tier, PDBs. Backup-DR: base + archive with named restore points, sandbox restore drills, stated RPO/RTO. Observability: exporter + `pg_stat_statements` + `auto_explain` sample + CSV/JSON logs → Prometheus/Grafana/Loki with per-scenario alerts from [Monitoring](./monitoring-postgres-internals.md).

## Interview Questions

Use any scenario as a prompt: "design X, then tell me what breaks first at 10× load and what you'd measure to see it coming." Strong answers name the bound (WAL/vacuum/locks/pool), the metric, and the next ladder step with its trade-off.

## Key Takeaways

- Every design is a bound with a meter and a next step — state all three.
- Single-writer, pool-first, vacuum-aware, drill-tested: the four habits behind all seventeen scenarios.
