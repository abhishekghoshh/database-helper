# PostgreSQL as More Than a Database

## Overview

JSONB + GIN, PostGIS, full-text search, LISTEN/NOTIFY, advisory locks, recursive CTEs, and logical replication let one PostgreSQL replace several specialized systems — when the workload fits. This file maps each "second job" to its internals, limits, and exit criteria.

See also:

- [How PostgreSQL Can Replace Parts of a Tech Stack](./postgres-replacing-tech-stack.md)
- [Index Internals](./index-internals.md) (GIN/BRIN/GiST)
- [Logical Decoding and CDC](./logical-decoding-cdc.md)
- [Advanced PostgreSQL Features](./advanced-postgres-features.md)

## Why This Matters

Consolidation cuts operational surface (one backup, one HA story, one skill set) but concentrates failure modes and stretches each feature past its design center. Know each role's ceiling before committing.

## Platform Roles

| Role | Internals | Ceiling / exit signal |
|---|---|---|
| JSON/document (JSONB) | binary JSONB + GIN (`jsonb_path_ops`), TOAST for wide docs | heavy per-doc analytics → document store; schema chaos → validation layer |
| Geospatial (PostGIS) | GiST R-tree, geography/topology | planet-scale tile serving → specialized geo stack |
| Time series (native + TimescaleDB) | partitioning + BRIN + compression/continuous aggregates | extreme ingest cardinality → purpose-built TSDB |
| Queue (SKIP LOCKED) | `SELECT ... FOR UPDATE SKIP LOCKED` dequeues without blocking | throughput > ~10k jobs/s or delayed scheduling → real broker |
| Coordination (advisory locks) | session/txn mutexes in lock manager | cross-DC fencing → consensus system |
| Pub/sub (LISTEN/NOTIFY) | async notification queue per backend | durable fan-out → Kafka/RabbitMQ |
| Full-text search | `tsvector`/`tsquery` + GIN, ranking | faceting/ML relevance at scale → search engine |
| Graph-ish (recursive CTEs) | `WITH RECURSIVE` over adjacency | deep traversals at scale → graph DB |
| Event store / CDC source | append-only tables + logical decoding | massive event replay → event log system |
| Cache/config store | unlogged/lookup tables + `pg_prewarm` | µs-scale hot path → Redis/memcached |

```sql
-- queue dequeue pattern
SELECT * FROM jobs WHERE status='pending' ORDER BY id
FOR UPDATE SKIP LOCKED LIMIT 1;
-- pub/sub
LISTEN order_events;  -- NOTIFY order_events, '{"id":42}';
-- search
SELECT * FROM docs WHERE tsv @@ plainto_tsquery('postgres internals');
-- jsonb containment with GIN
SELECT * FROM profiles WHERE attrs @> '{"plan":"pro"}';
```

## Hands-on Experiment

Build the queue above with 2 workers pulling concurrently; watch `SKIP LOCKED` prevent blocking (`pg_locks` shows only momentary row locks). Then benchmark NOTIFY fan-out vs expected broker throughput to feel the ceiling.

## Interview Questions

### Intermediate

- Why is `SKIP LOCKED` the queue primitive? — Workers skip rows locked by peers instead of queueing, giving lock-free dequeue parallelism.
- LISTEN/NOTIFY durability? — None: notifications are transient, coalesced, payload-limited (8000 B) — unsuitable as a message log.

### Advanced

- When does JSONB-in-Postgres beat Mongo? — Transactional documents with joins, constraints, and CDC needs; loses on schema-fluid massive-scale document analytics.
- PostGIS vs dedicated geo? — Complex SQL+geo joins favor PostGIS; global tile/low-latency serving favors specialized stacks.

## Key Takeaways

- PostgreSQL's second jobs share one engine: transactions, indexes, VACUUM, and replication apply to all of them.
- Each role has a measurable ceiling — define exit metrics at adoption time.
- Consolidation wins operationally until one workload's ceiling dominates; then extract surgically.
