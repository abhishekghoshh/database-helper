# Interview-Level PostgreSQL Internals

## Overview

Thirty-one classic questions with mechanism-first answers and file links. Use for prep and as a spaced-repetition index over the series. Answers compress; follow links for full traces.

## Processes, Connections, Pooling

- **Why processes instead of threads?** Isolation (extension bugs contained), leak-free session memory, no cross-session allocator contention; cost = per-connection weight → poolers. [Architecture](./postgresql-architecture.md).
- **Millions of connections / why PgBouncer?** Backends don't scale past hundreds active; txn pooling multiplexes thousands of client states onto tens of backends. [Connections](./postgresql-connection-internals.md).

## MVCC, VACUUM, HOT, Writes

- **Why VACUUM?** Lock-free reads need retained old versions; only a global-horizon collector can safely reclaim them. [VACUUM](./vacuum-internals.md).
- **Why is UPDATE expensive?** Old-mark + new version + full index maintenance (unless HOT) + WAL for all + future vacuum. [Write Path](./postgresql-write-path.md).
- **MVCC / XIDs / snapshots / VACUUM interplay?** Snapshots scope visibility; XIDs version rows; pg_xact records fate; VACUUM reclaims versions invisible to all horizons. [MVCC](./mvcc-internals.md).
- **Autovacuum behavior?** Launcher schedules per-table by dead-tuple thresholds; workers clean with cost-delay budgets; falls behind when garbage rate exceeds reclaim. [VACUUM](./vacuum-internals.md).
- **Bloat origins?** Unreclaimed dead versions/entries (vacuum lag, xmin holders) + splits/fragmentation; interior holes reusable, tails truncatable. [Storage](./postgresql-storage-architecture.md).
- **HOT mechanics?** Same-page, non-indexed-column update → indexes keep pointing at chain head; pruning reclaims opportunistically. [MVCC](./mvcc-internals.md).
- **Wraparound handling?** 32-bit XIDs + freeze (old → FrozenTransactionId) + `relfrozenxid` age tracking + emergency vacuum + hard write stop. [MVCC](./mvcc-internals.md).

## Durability and Replication

- **Why WAL?** Sequential ordered truth enabling crash replay + replication + PITR, decoupling commit durability from random page writes. [WAL](./wal.md).
- **WAL durability / checkpoints?** fsync'd WAL = committed; checkpoints bound replay by flushing to the redo pointer. [WAL](./wal.md), [Checkpoints](./checkpoints-background-writer.md).
- **Replication / physical vs logical?** Physical: byte-identical WAL replay (whole cluster, no conflicts). Logical: row changes per table (selective, version-spanning, conflict-possible). [Replication](./replication-internals.md), [Logical](./logical-replication.md).
- **Crash recovery?** Startup replays WAL from redo LSN with FPI torn-page repair. [Crash Recovery](./crash-recovery-internals.md).

## Planning and Execution

- **Plan choice / statistics influence?** Cost model over sampled stats (histograms, MCVs, correlation, extended); misestimates compound per join. [Execution](./query-execution-internals.md), [Statistics](./postgresql-statistics.md).
- **Index unused / index-only scans?** Selectivity, correlation, opfamily mismatch, stale stats, generic plans; index-only needs covering columns + VM bits. [Indexes](./index-internals.md).
- **Deadlocks?** Wait-for-graph detection on lock timeout expiry; abort + retry. No escalation (row locks in tuples/MultiXact). [Locks](./locks-concurrency-internals.md).

## Scaling and Design

- **Read vs write scaling?** Replicas scale reads (lag-aware routing); writes scale via partitioning then sharding (single-writer WAL bound). [Scaling](./postgresql-scaling.md).
- **Write-heavy struggles?** Multiplier stack (versions × indexes × WAL/FPI × vacuum × replay) with reclaim as the binding constraint. [Write-heavy](./why-postgres-struggles-with-writes.md).
- **Partitioning / sharding triggers?** Partition: maintenance-bounded tables + prune-able queries + retention-by-detach. Shard: single-writer WAL/vacuum saturated with distribution-key-aligned queries. [Partitioning](./partitioning-internals.md), [Scaling](./postgresql-scaling.md).
- **Postgres vs specialist / stack replacement?** Consolidate while under each feature's ceiling with CDC seams for extraction; specialists win past vector/search/broker/geo ceilings. [Platform](./postgres-as-platform.md), [Tech stack](./postgres-replacing-tech-stack.md).

## Key Takeaways

- Answer every question with mechanism → trade-off → metric → fix. That structure is the interview signal.
- Cite the trace (XID, LSN, plan node, slot) not the slogan.
