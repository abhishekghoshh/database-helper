# Deep-Dive "What Actually Happens?" Questions

## Overview

Thirty-two end-to-end traces in one place: connect, write, visibility, vacuum, checkpoints, WAL, crash, replication, indexes, resources, and pooling. Each answer compresses its deep-dive file into numbered runtime steps — use this as the index, follow links for full mechanics.

## Connections and Processes

### What exactly happens when a client connects?

TCP accept → TLS upgrade → startup packet → `pg_hba.conf` first-match → SCRAM exchange → `fork()` backend → CONNECT-privilege + `max_connections` checks → GUC/session init → `ReadyForQuery`. Full trace: [Connection Internals](./postgresql-connection-internals.md).

### Why a process per connection?

Crash isolation (extension bugs contained), leak-free session memory (contexts die with the backend), no cross-session allocator contention — at the cost of per-connection MBs and scheduler pressure. See [Architecture](./postgresql-architecture.md).

### What happens with 10,000 clients?

10k sockets → without pooling, fork/memory/scheduler collapse around hundreds of *active* backends; with PgBouncer transaction pooling, 10k client states multiplex onto ~50–200 server backends. Fan-in arithmetic: [Connections](./postgresql-connection-internals.md), [Scaling](./postgresql-scaling.md).

## Writes and Visibility

### What happens on INSERT / UPDATE / DELETE?

INSERT: FSM placement → tuple (`xmin`=self) → index entries → WAL → commit flush. UPDATE: old `xmax`=self + new version chained + index maintenance unless HOT. DELETE: `xmax`=self, index cleanup deferred to vacuum. Traces: [Write Path](./postgresql-write-path.md), [MVCC](./mvcc-internals.md).

### Why does UPDATE create another tuple / why doesn't DELETE remove immediately?

Lock-free reads: concurrent snapshots may still need the old version; removal is only safe once no snapshot sees it — VACUUM's global-horizon decision. Immediate removal would require read locks or undo logs, abandoning MVCC's core trade.

### How does PostgreSQL know tuple visibility / commit status?

`xmin`/`xmax` vs snapshot (`xmin`/`xmax`/active list from ProcArray) + `pg_xact` commit bits + hint bits caching verdicts. `SELECT xmin, xmax, ctid` shows it live. See [MVCC](./mvcc-internals.md).

## VACUUM and Space

### What happens during VACUUM / why can't it always return space / VACUUM FULL?

Scan + prune → index cleanup → heap sweep → VM/FSM → freeze. Returns only empty tail pages (interior holes = reusable free space); FULL/CLUSTER rewrite the file under `ACCESS EXCLUSIVE`. Full phases: [VACUUM](./vacuum-internals.md).

## Checkpoints, WAL, Crash

### What happens during a checkpoint / when WAL is written / on crash / recovery?

Checkpoint: redo-LSN record → dirty flush spread over completion target → `pg_control` advance → WAL recycle. WAL: buffer reserve → copy → flush/fsync per commit semantics (group commit batches). Crash: startup replays from redo LSN with FPI torn-page repair. Files: [Checkpoints](./checkpoints-background-writer.md), [WAL](./wal.md), [Crash Recovery](./crash-recovery-internals.md).

## Replication and Indexes

### What happens when a replica receives WAL / how replay works / why lag?

Sender streams → receiver persists → startup replays serially. Lag = network gap + flush gap + replay gap (conflicts, long standby queries, I/O-starved replay). See [Replication](./replication-internals.md).

### What happens on index create / full page / page split?

Build: scan + sort + bulk load (+ concurrent two-pass for CIC). Split: full leaf halves into sibling, parent downlink posted, cascading to root; WAL-logged; rightmost-page special-casing for append workloads. See [Indexes](./index-internals.md).

## Resources and Limits

### Out of memory / disk / WAL-full / vacuum-behind / hour-long transaction / abandoned slot / wraparound / too many connections / pool overflow?

OOM: per-backend `work_mem`×nodes×backends exceeds RAM → killer picks victims; fix global + per-role sizing and pooling. Disk-full: bloat/temp/retention — free per mount class, then fix the source. WAL-full: retained segments (slot/archiver) — release retention, never just raise limits. Vacuum-behind: thresholds/cost-delay/workers/xmin-holders, in that order. Hour-long write txn: pins xmin + bloat + wraparound age — terminate and fix scope. Abandoned slot: retained WAL grows until drop + re-snapshot. Wraparound approach: emergency freeze, then threshold reform. Too many connections: pool, don't raise `max_connections`. Pool overflow (`cl_waiting`): pool too small *or* queries too slow — fix queries first. Each links its deep file above.

## Interview Questions

Pick any heading as the prompt; strong answers give the numbered runtime flow, the subsystem/file, and the metric that proves each step.

## Key Takeaways

- Every answer is a pipeline: process → memory → pages → WAL → locks/snapshots → background work → observable metric.
- Trace with `xmin/xmax/ctid`, LSNs, `EXPLAIN (ANALYZE, BUFFERS)`, and progress views — internals are inspectable, not theoretical.
