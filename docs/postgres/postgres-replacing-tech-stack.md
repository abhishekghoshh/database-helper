# How PostgreSQL Can Replace Parts of a Tech Stack

## Overview

Concrete consolidation recipes: what to replace with which PostgreSQL feature, the migration shape, and — critically — where *not* to replace. Companion to [PostgreSQL as More Than a Database](./postgres-as-platform.md), focused on decisions.

## Replacement Map

| Instead of … | Use … | Keep the specialist when … |
|---|---|---|
| Mongo/document DB | JSONB + GIN + constraints | schema-fluid analytics at TB scale |
| Redis (cache/sessions/flags) | UNLOGGED tables, `pg_prewarm`, short-TTL rows | µs p99 or >100k ops/s hot path |
| RabbitMQ/SQS (simple queues) | `SKIP LOCKED` queue table | delayed/ordered/durable fan-out at scale |
| Redis Redlock/ZK locks | advisory locks | cross-DC fencing, lease semantics |
| Elasticsearch (basic search) | `tsvector` + GIN + ranking | facets/ML relevance/scale-out search |
| Standalone geo DB | PostGIS | planet-scale serving pipelines |
| Pinecone/Weaviate (basic vectors) | pgvector (HNSW/IVFFlat) | billion-vector ANN at low latency |
| Influx/Prometheus long-store | TimescaleDB hypertables | extreme-cardinality ingest |
| Debezium-sidecar CDC | logical replication/decoding | multi-source streaming platform (then Kafka *with* PG as source) |
| Config service | versioned config tables + NOTIFY reload | massive fan-out config push |

## Architecture Patterns

- **Single-platform core**: app + PG (JSONB, queue, search, CDC out) + object storage + CDN. One backup/HA story; extract services at measured ceilings.
- **Workflow state store**: orders/sagas as rows with advisory-lock single-flight + outbox for events — transactional state machine without a workflow engine (until visual/complex sagas demand one).
- **Microservices backend**: schema-per-service in one cluster (isolation via roles/RLS) or DB-per-service with logical replication for cross-service projections. Serverless: pooler (PgBouncer/Supavisor/Neon) mandatory.

## When NOT to Replace / Trade-offs / Single-Platform Call

Don't replace when: the specialist's ceiling is your workload (vector scale, search relevance, broker durability), team lacks PG depth for the stretched feature, or consolidation concentrates blast radius unacceptably (one cluster for money + analytics + queue needs bulkheads).

**The call**: consolidate while every workload sits comfortably under its PG ceiling with shared operational wins; extract the first workload to hit its ceiling with a CDC/event seam (logical replication makes extraction incremental, not big-bang).

## Interview Questions

### Advanced

- How do you avoid lock-in when consolidating on PG? — CDC/event seams per domain, versioned schemas, exit metrics — extraction via logical replication, not rewrites.
- Redis vs UNLOGGED tables for sessions? — Latency/throughput thresholds + persistence needs: Redis for µs hot paths, PG when sessions must join transactional data.

## Key Takeaways

- Replace for operational leverage, not ideology — each swap has a named ceiling and exit plan.
- Outbox + logical replication keep consolidated architectures extractable.
- The platform decision is reversible only if you build the seams first.
