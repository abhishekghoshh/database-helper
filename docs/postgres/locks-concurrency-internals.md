# Locks and Concurrency Internals

## Overview

PostgreSQL layers three lock systems: heavyweight table/row locks (multi-granularity, in shared memory), light `LWLocks` protecting internal structures, and spinlocks for single instructions. No lock escalation, MVCC eliminating read locks, and deadlock detection instead of prevention. This file maps modes, queues, and failure behavior.

See also:

- [MVCC Internals](./mvcc-internals.md)
- [Isolation and Transaction Internals](./isolation-transaction-internals.md)
- [Monitoring PostgreSQL Internals](./monitoring-postgres-internals.md)

## Why This Matters

"Query stuck" is almost always lock queueing; "deadlock found" is application ordering; "reporting blocks deploys" is lock-mode conflict. The compatibility matrix below answers all three.

## Locking Architecture / Lock Manager / Modes / Compatibility / Queues

`src/backend/storage/lmgr/` implements heavyweight locks keyed by (type, database, relation, page, tuple). Main table modes:

| Mode | Taken by | Conflicts with |
|---|---|---|
| `AccessShare` | `SELECT` | `AccessExclusive` only |
| `RowShare` | `SELECT FOR UPDATE/SHARE` | `Exclusive`, `AccessExclusive` |
| `RowExclusive` | `INSERT/UPDATE/DELETE` | `Share`, `ShareRowExclusive`, `Exclusive`, `AX` |
| `Share` | `CREATE INDEX` (non-concurrent) | `RowExclusive`+ |
| `ShareRowExclusive` | `CREATE TRIGGER`, FK checks | `RowExclusive`+ |
| `Exclusive` | `REFRESH MATVIEW CONCURRENTLY` steps | most writes |
| `AccessExclusive` | `ALTER TABLE`, `DROP`, `VACUUM FULL`, `CLUSTER` | **everything, including reads** |

Queues are FIFO-ish with priorities: a waiting `AccessExclusive` (e.g., migration) blocks *new* `AccessShare` grants behind it — which is how one `ALTER TABLE` freezes an entire app (lock pile-up, not just the alter waiting).

```sql
SELECT pid, locktype, relation::regclass, mode, granted,
       now() - query_start AS wait
FROM pg_locks JOIN pg_stat_activity USING (pid)
WHERE NOT granted ORDER BY query_start;
```

## Table / Row / Tuple / Predicate / Advisory Locks

- **Row locks**: stored in tuple `xmax`/MultiXact, not the lock table — `SELECT FOR UPDATE` marks the version; concurrent updaters get `WriteConflict`/serialization errors per isolation level.
- **Predicate locks** (serializable): `SIREAD` locks in shared memory tracking read predicates for SSI conflict detection.
- **Advisory locks** (`pg_advisory_lock(key)`): application-managed mutexes outside MVCC — session or transaction scoped. Coordination primitive (leader election, single-flight jobs) with no table involved. Must handle crash-release semantics explicitly.

## `SELECT FOR UPDATE/SHARE` / No Escalation / LWLocks / Spinlocks

- `FOR UPDATE` (write intent), `FOR SHARE` (read-stability intent), `FOR NO KEY UPDATE`/`KEY SHARE` (weaker, FK-friendly variants that reduce upgrade conflicts).
- **No lock escalation**: PostgreSQL never upgrades many row locks to a table lock (unlike SQL Server). Memory stays bounded because row locks live in tuples/MultiXact, not RAM structures — at the cost of MultiXact pressure under extreme concurrent row-locking.
- **LWLocks** (`buffer_content`, `WALInsert`, `ProcArray`, `relation_extension`…): sharded, short-held, visible in `pg_stat_activity.wait_event_type = 'LWLock'`.
- **Spinlocks**: single-instruction atomic sections (PGPROC assignment). `wait_event = 'SpinLock'` + high CPU = pathological contention, usually a bug or extreme skew.

## Extension / XID / Buffer / WAL Locks

- **Relation extension**: serializes file growth — hot spot for append-only + sequence-PK inserts; partitioning or hash-distributed keys relieve it.
- **Transaction ID locks**: `SELECT ... FOR UPDATE` on in-flight XIDs waits on the owner's commit/abort.
- **Buffer/WAL insert locks**: page- and WAL-segment-striping; `WALInsert` contention means tiny unbatched commits on many cores.

## Deadlocks / Detection / Timeout

Deadlock detector (`deadlock.c`) runs when `lock_timeout`/`deadlock_timeout` (1 s) expires on a waiter: builds wait-for graph, aborts a participant with `deadlock detected`, other retries. Design: detection (cheap, periodic) instead of prevention (ordering constraints on all apps).

```sql
SET deadlock_timeout = '1s';  -- keep default; raising it only delays detection
-- app code: always retry serialization/deadlock errors with backoff
```

ROW-level deadlocks need no table locks: T1 locks row A then wants B while T2 holds B wants A — same graph logic at tuple granularity.

## What Actually Happens Internally?

Migration `ALTER TABLE orders ADD COLUMN x` during traffic:

1. Requests `AccessExclusive`; queued behind running `AccessShare`s.
2. New `SELECT`s queue *behind the alter* (lock-queue ordering) — app appears frozen though the alter hasn't started.
3. Alter runs in ms once granted; queue drains. Total outage = wait time, not work time. Fix: `SET lock_timeout`, `ALTER ... WITH (false)` patterns, or concurrent-safe rewrites (`pg_repack`, `ALTER ... ADD COLUMN ... DEFAULT` is cheap since v11).

## Hands-on Experiment

Terminal 1: `BEGIN; SELECT * FROM t WHERE id=1 FOR UPDATE;` (hold).
Terminal 2: `UPDATE t SET v=2 WHERE id=1;` — blocks. `SELECT * FROM pg_locks WHERE NOT granted;` shows the waiter.
Terminal 1: `COMMIT;` — Terminal 2 proceeds. Reverse the order on two rows across two terminals for a true deadlock; watch `ERROR: deadlock detected`.

## Troubleshooting

### Symptom: all queries suddenly queue, CPU idle

Lock pile-up behind DDL or `VACUUM FULL`/`CLUSTER`. **Diagnose:** non-granted `AccessExclusive` oldest in queue + granted AccessShares ahead. **Fix:** cancel the DDL (`pg_cancel_backend`), set `lock_timeout = '5s'` for migrations, use concurrent index builds.

## Interview Questions

### Intermediate

- Why does `SELECT` never block on row locks? — MVCC: readers use snapshots, not locks; only `FOR UPDATE/SHARE` takes row locks explicitly.
- What is lock queue jumping, and why does one migration freeze reads? — Waiting exclusive-mode requests block later shared grants; the queue, not the work, causes the outage.

### Advanced

- Why no lock escalation, and what replaces it? — Row locks in tuple headers/MultiXact bound memory without coarsening; trade is multixact churn under mass concurrent locking.
- Advisory locks vs `SELECT FOR UPDATE`? — Advisory: arbitrary app mutex, no row needed, manual lifecycle. Row locks: tied to tuple visibility and transaction scope.

## Key Takeaways

- Compatibility matrix + queue ordering explain nearly every "stuck database" page.
- Migrations need `lock_timeout` and concurrent patterns — DDL queueing is the outage, not DDL speed.
- Deadlocks are retried in app code, not prevented in schema.
