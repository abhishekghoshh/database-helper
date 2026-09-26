# PostgreSQL Scaling

## Overview

Scale PostgreSQL along four axes — vertical, read (replicas), connection (pooling), write (partitioning/sharding) — choosing by measured bound, not fashion. This file gives the decision order, the distributed options (Citus), and when one instance is enough.

See also:

- [Replication Internals](./replication-internals.md)
- [PostgreSQL Connection Internals](./postgresql-connection-internals.md)
- [Partitioning Internals](./partitioning-internals.md)
- [Why PostgreSQL Can Struggle With Write-Heavy Workloads](./why-postgres-struggles-with-writes.md)
- [Real-World PostgreSQL Architecture](./real-world-postgres-architecture.md)

## Why This Matters

Premature sharding destroys velocity; late sharding destroys weekends. The scaling ladder below keeps you on the cheapest step that fits measurements.

## The Ladder

```text
1. Single instance + tuning (weeks of headroom, zero complexity)
2. Read replicas + read/write splitting (read scale, lag-aware routing)
3. PgBouncer everywhere (connection scale — do this at step 1, really)
4. Partitioning + archival (maintenance-bounded tables)
5. Sharding: app-level, postgres_fdw, or Citus (write scale)
6. Multi-primary / distributed SQL (conflict semantics change — last resort)
```

## Vertical / Read / Replicas / Splitting / Connection / Write / Partitioning

- **Vertical**: bigger CPU/RAM/faster NVMe raises every ceiling sublinearly; cheapest first step with measured headroom. NUMA-pin past ~32 cores.
- **Read scaling**: async replicas + router (PgBouncer `pool_mode` per pool, Pgpool-II, app-level read-only DS). Consistency contract: replica reads may lag — route session-critical reads (read-your-write) to primary.
- **Connection scaling**: PgBouncer transaction pooling from day one; `max_connections` stays low (100–300) while app concurrency grows 10–100×.
- **Write scaling**: single-writer bound (WAL fsync + vacuum + replay) doesn't move with replicas. Partition (maintenance bounds), then shard.

## Sharding: App / Extensions / Citus / Distributed / Multi-Primary

| Approach | Routing | Transactions | Best for |
|---|---|---|---|
| App-level sharding | app hash → N clusters | per-shard only | clean tenant sharding, team owns routing |
| `postgres_fdw` + partitioning | planner + FDW pushdown | best-effort cross-shard | gradual extraction, admin federation |
| Citus (columnar + distributed) | coordinator + workers, distribution column | single-shard ACID, cross-shard limited/2PC-ish | multi-tenant SaaS, time series at scale |
| Multi-primary (BDR/bi-directional logical) | conflict resolvers | last-writer/conflict rules | active-active regions with resolvable conflicts |

Citus architecture: coordinator plans, workers (regular PG + `citus` ext) own shards by distribution column; co-located joins stay fast, cross-shard joins pay network. Choose the distribution column = the tenant/customer key queries already filter on.

## Replication-Based Scaling / Single-Instance Sufficiency / Distributed Need

Stay single-instance while: peak active backends < ~200, WAL/replay headroom > 3×, vacuum holds `n_dead_tup` flat, p99 stable. Move when two consecutive quarters of growth exhaust vertical + replica + partition levers — the decision is capacity math with dates, not ideology.

## When to Use / Not Use / Trade-offs

Poolers/partitions/replicas: almost always net-positive. Sharding/multi-primary: irreversible-ish complexity (resharding, cross-shard queries, conflict ops) — adopt at measured need with a distribution key chosen from query patterns, never from convenience.

## Interview Questions

### Intermediate

- Why don't read replicas scale writes? — Single-writer WAL architecture: replicas replay; they absorb reads and add lag/freshness trade-offs, not write throughput.
- What breaks first when connection-scaling via `max_connections`? — Memory (per-backend) then scheduler contention; poolers fix fan-in without backends.

### Advanced

- How do you choose a Citus distribution column? — Highest-cardinality tenant-ish key present in most WHERE/JOIN clauses, so queries route to one shard and joins co-locate.
- When is multi-primary correct despite conflicts? — Regional active-active with commutative/resolvable writes (counters via CRDT-ish, per-region ownership) and explicit conflict runbooks.

## Key Takeaways

- Ladder order: tune → pool → replicate reads → partition → shard. Skip steps only with measurements.
- Distribution key = query pattern key. Everything else is migration pain.
- Single-writer is the scaling fact all plans orbit.
