# Partitioning Internals

## Overview

Declarative partitioning splits a logical table into physical partitions with constraint-aware routing, pruning, and per-partition maintenance. Done well it bounds vacuum, enables archival by detach, and prunes I/O; done badly it multiplies planning cost and autovacuum load. This file explains routing, pruning, indexes, and maintenance.

See also:

- [Query Execution Internals](./query-execution-internals.md)
- [VACUUM Internals](./vacuum-internals.md)
- [Index Internals](./index-internals.md)
- [PostgreSQL Scaling](./postgresql-scaling.md)

## Why This Matters

Partitioning is the standard answer to "table too big to vacuum/index/archive". But each partition is a real table (relfilenode, indexes, vacuum scheduling) — hundreds of partitions have hundred-table costs.

## Declarative Partitioning / Routing / Pruning / Partition-wise Ops

```sql
CREATE TABLE events (id bigserial, created_at timestamptz NOT NULL, payload jsonb)
  PARTITION BY RANGE (created_at);
CREATE TABLE events_2026_01 PARTITION OF events
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
```

- **Routing**: INSERT evaluates the partition bound (`src/backend/partitioning/`); no match → error (or `DEFAULT` partition). UPDATE changing the key *moves* the row across partitions (v11+ row-movement, costlier than in-place).
- **Pruning**: planner/executor excludes partitions via constraints (`constraint_exclusion = partition`), including runtime pruning for parameterized queries. `EXPLAIN` shows `Append` over surviving partitions only.
- **Partition-wise join/aggregate** (v11+/v14+): joins/aggregations pushed per-partition when partition keys align — the difference between linear and constant scaling on partitioned analytics.

## INSERT/UPDATE/DELETE Paths / Constraints / Metadata / Indexes

- Writes route then behave like single-table writes (HOT, indexes, WAL per partition).
- `CHECK` constraints per partition double as pruning metadata; `pg_class.relispartition`, `pg_inherits`, `pg_partition_tree()` expose topology.
- **Indexes are local** (per partition; no global indexes): unique constraints must include the partition key. This is the fundamental modeling constraint — global uniqueness needs application enforcement or a different key design.

## Maintenance: Create / Detach / Archive / Time-Based Patterns

```sql
ALTER TABLE events DETACH PARTITION events_2025_01;  -- instant, then archive/drop
```

Time-based monthly/daily partitions + `pg_partman` (or scheduled DDL) + detach-oldest archival is the canonical retention pattern: dropping a partition is O(1) metadata vs `DELETE`'s vacuum-generating churn. `DETACH ... CONCURRENTLY` (v14+) avoids access-exclusive stalls.

## VACUUM/Autovacuum per Partition / Write-Heavy Fit

Autovacuum schedules *per partition*: hot recent partitions get frequent small vacuums (good), 500 cold partitions each get analyzed pointlessly (overhead). Tune: aggressive per-table settings on hot partitions, `autovacuum_enabled = false` + explicit scheduling on frozen historical ones. For write-heavy ingest, partitioning bounds each vacuum/index to partition size and enables drop-based retention — the primary scaling win.

## When to Use / Not Use / Trade-offs

Use when: time/size-based retention, vacuum-bounded hot writes, prune-able query patterns. Avoid when: queries routinely span all partitions (pruning never fires, planning overhead always does), partition count in thousands (planning + autovacuum + lock acquisition scale with count), or global uniqueness/indexes required.

## Hands-on Experiment

```sql
EXPLAIN SELECT * FROM events WHERE created_at BETWEEN '2026-01-05' AND '2026-01-10';
-- Append over 1 partition vs all: compare with enable_partition_pruning off
SELECT * FROM pg_partition_tree('events');
```

## Troubleshooting

### Symptom: planning time dominates after partitioning into 2000 daily partitions

Too many partitions for the query pattern. **Fix:** coarser granularity (monthly), prune-enforcing predicates, `constraint_exclusion`, or reverse the decision (single table + BRIN often beats micro-partitions).

## Interview Questions

### Intermediate

- Why must unique constraints include the partition key? — Indexes are partition-local; cross-partition uniqueness has no enforcement point.
- Detach vs delete for retention? — Detach is metadata-only instant; delete generates dead tuples + vacuum + WAL proportional to rows.

### Advanced

- When does partition-wise join fire, and why does key alignment matter? — Join keys matching partition keys lets the executor join matching partition pairs independently instead of repartitioning/shuffling all input.

## Key Takeaways

- Partitioning bounds maintenance (vacuum, archival, indexes) — that is the win, not raw query speed.
- Local indexes + pruning-dependent queries are the design contract; violate either and partitioning hurts.
- Partition count is a cost dimension: dozens good, thousands a planning/autovacuum tax.
