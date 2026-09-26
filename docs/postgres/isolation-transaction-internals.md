# Isolation and Transaction Internals

## Overview

PostgreSQL transactions are XID-stamped snapshot scopes with three isolation levels implemented three different ways: per-statement snapshots (Read Committed), one snapshot per transaction (Repeatable Read), and predicate-tracked SSI (Serializable) — plus subtransactions, 2PC, and wraparound discipline. This file connects isolation theory to the XID/snapshot machinery.

See also:

- [MVCC Internals](./mvcc-internals.md)
- [Locks and Concurrency Internals](./locks-concurrency-internals.md)
- [VACUUM Internals](./vacuum-internals.md) (wraparound)

## Why This Matters

Choosing an isolation level without knowing its implementation means choosing anomalies you can't predict. This file makes each level's guarantees *and* failure modes mechanical.

## Lifecycle / XIDs / Snapshots / Boundaries

`BEGIN` (assigns no XID until first write — lazy XID assignment saves IDs for read-only txns) → statements (snapshots per level) → `COMMIT` (assign commit LSN, mark `pg_xact`, flush WAL) or `ABORT` (mark aborted, release locks). `src/backend/access/transam/xact.c` owns the state machine; `GetSnapshotData()` owns visibility.

## Read Committed Internals

Default. **New snapshot per statement**: each statement sees data committed before *it* started. Consequences: non-repeatable reads and phantom rows across statements in one transaction — but also the level where `UPDATE ... WHERE` re-evaluates the latest committed version on write-conflict retry (PostgreSQL's `EvalPlanQual` recheck), so concurrent updates serialize rather than fail.

## Repeatable Read Internals

**One snapshot for the whole transaction**: repeatable reads, no phantoms — at the price of write conflicts. Updating a row changed after your snapshot aborts with `could not serialize access due to concurrent update`. Long RR transactions pin old snapshots → vacuum/wraparound pressure. Use for consistent multi-statement reports, not for OLTP update loops.

## Serializable / SSI / Serialization Failures / Snapshot Visibility

True serializability via **Serializable Snapshot Isolation** (`src/backend/storage/predicate/`): tracks read predicates (SIREAD locks) and write dependencies, aborts transactions whose commit order would be non-serializable (`could not serialize access due to read/write dependencies`). Applications **must retry** serialization failures — the level is unusable without retry loops. Predicates consume shared memory (`max_pred_locks_per_transaction`); overflow degrades to coarser tracking (more false aborts, never missed anomalies).

| Level | Snapshot scope | Anomalies prevented | Failure mode |
|---|---|---|---|
| Read Committed | per statement | lost update (via recheck) | non-repeatable reads, phantoms |
| Repeatable Read | per transaction | + phantoms, non-repeatable | concurrent-update abort |
| Serializable (SSI) | per transaction + predicates | + serialization anomalies | read/write-dependency abort (retry) |

## Subtransactions / Savepoints / 2PC / Prepared Transactions

- **Savepoints** (`SAVEPOINT s; ROLLBACK TO s`): subtransactions with their own resource owners — partial rollback without aborting. Cost: each savepoint forces WAL/XID bookkeeping; thousands per transaction (ORM anti-patterns) bloat pg_xact and slow commit.
- **2PC** (`PREPARE TRANSACTION 'gid'; COMMIT PREPARED`): durable prepared state in `pg_twophase/` surviving crashes, for distributed coordinators. **Danger**: forgotten prepared xacts pin `xmin` forever (wraparound/blocked vacuum) — monitor `pg_prepared_xacts` and alert.

## Wraparound / XID Consumption / Long Transactions / Idle-in-Transaction

Covered mechanically in [MVCC Internals](./mvcc-internals.md) and [VACUUM Internals](./vacuum-internals.md); transaction-layer summary:

- Read-only transactions consume no XID (lazy assignment) — safe to be long-ish.
- Any *write* transaction, plus `VACUUM`-blocking snapshot holders, advances the danger: `age(datfrozenxid)` in `pg_database` is the cluster-wide countdown.
- `idle in transaction` with prior writes holds XID + snapshot + locks — the worst combination; `idle_in_transaction_session_timeout` exists for exactly this.

```sql
SELECT datname, age(datfrozenxid) AS xid_age FROM pg_database;
SELECT pid, now()-xact_start AS age, query FROM pg_stat_activity
WHERE xact_start IS NOT NULL ORDER BY xact_start LIMIT 10;
```

## What Actually Happens Internally?

RR transaction updating a concurrently-changed row:

1. `BEGIN ISOLATION LEVEL REPEATABLE READ; SELECT` — snapshot S taken.
2. Concurrent txn commits a change to row R.
3. `UPDATE ... R` — executor finds R's new version is invisible-to-S but committed-after-S → error `could not serialize`, transaction must roll back and retry (no EvalPlanQual escape hatch at RR+, unlike Read Committed).

## Hands-on Experiment

T1: `BEGIN ISOLATION LEVEL REPEATABLE READ; SELECT * FROM t WHERE id=1;`
T2: `UPDATE t SET v=2 WHERE id=1; COMMIT;`
T1: `UPDATE t SET v=3 WHERE id=1;` → serialization error. Repeat at Read Committed: T1's UPDATE succeeds (rechecks latest version). This contrast *is* the isolation implementation.

## Troubleshooting

### Symptom: `prepared transaction with identifier "x" has been prepared` lingering for days

Orphaned 2PC from a dead coordinator. **Fix:** verify with coordinator owner, then `ROLLBACK PREPARED 'x'` (or commit). Alert on `count(*) FROM pg_prepared_xacts > 0`.

## Interview Questions

### Intermediate

- Why do lazy XIDs matter? — Read-only traffic doesn't consume the 4B XID space or freeze work; only writers advance wraparound.
- Read Committed vs Repeatable Read in one mechanism? — Snapshot scope: per-statement vs per-transaction.

### Advanced

- Why must serializable apps retry, and what happens without it? — SSI *detects* non-serializable orders by aborting; without retry the business operation silently never happens.
- Savepoint abuse cost? — Each savepoint is a real subtransaction with resource-owner + WAL overhead; thousands per txn slows commit and bloats state.

## Key Takeaways

- Isolation = snapshot scope + conflict policy. Know both per level.
- Long write transactions are a cluster-health hazard (vacuum, wraparound, bloat) — keep them short or read-only.
- Prepared transactions need an owner and an alert; orphans are wraparound time-bombs.
