# PostgreSQL Failure Scenarios

## Overview

Twenty failure modes, each with mechanism → signals → diagnosis → fix → prevention. This is the incident-response companion to the whole series: every entry links the deep-dive file, so a page at 3 AM becomes a checklist, not research.

See also:

- [Monitoring PostgreSQL Internals](./monitoring-postgres-internals.md)
- [Troubleshooting sections across all internals files](./README.md)

## Crash / Host / Disk / Corruption

| Scenario | Mechanism | Diagnose | Fix / prevent |
|---|---|---|---|
| Backend process crash | segfault (often extension) → postmaster restarts cluster + recovery | logs (signal 11 + query), core | fix extension, redeploy; replicas absorb traffic |
| Server/host crash | power/kernel → unclean shutdown | `was not properly shut down` + replay time | HA standby promotion; checkpoint tuning bounds replay |
| Disk failure (data) | unreadable heap files | checksum errors, I/O errors | restore base + WAL; checksums on; RAID/EBS redundancy |
| Disk full (data) | bloat/temp/unbounded growth | per-mount usage, `pg_total_relation_size` top tables, temp bytes | free + repack/partition/drop; temp-tablespace isolation |
| WAL disk full | retained WAL (slot/archiver/`max_wal_size`) | `pg_replication_slots` retained, `pg_stat_archiver` failures | drop dead slots, repair archive, raise size only after retention fixed |
| Corrupted relation / WAL | bitrot, lying storage, torn page without FPI | checksum failures at scan/replay | restore affected range; `zero_damaged_pages` last-resort; `pg_test_fsync`-verified storage |

## Vacuum / XID / Connections / Locks

| Scenario | Mechanism | Diagnose | Fix / prevent |
|---|---|---|---|
| Autovacuum falling behind | garbage rate > reclaim (thresholds, cost delay, xmin holders) | `n_dead_tup` velocity, progress view, oldest xmin | thresholds/workers/cost-delay + kill holders — [VACUUM](./vacuum-internals.md) |
| TXID wraparound approach | `age(datfrozenxid)` → emergency vacuum → write shutdown | `SELECT age(datfrozenxid) FROM pg_database` | freeze campaign now; threshold reform after |
| Connection exhaustion / storm | fork + memory × N clients | `pg_stat_activity` states; `too many clients` | PgBouncer, app pool caps, backoff — [Connections](./postgresql-connection-internals.md) |
| Lock storm / pile-up | DDL `AccessExclusive` queued behind traffic | non-granted oldest in `pg_locks` | cancel DDL, `lock_timeout`, concurrent patterns — [Locks](./locks-concurrency-internals.md) |
| Deadlocks | cyclic waits (rows or tables) | `deadlock detected` log with graph | retry with backoff; consistent lock ordering |
| Long transaction / idle-in-txn | snapshot + XID held across RPC | `xact_start` age ranking | timeouts + client scope fix |
| Table / index bloat | dead versions/entries + lagging vacuum | `n_dead_tup`, `pgstattuple`, index density | vacuum catch-up → repack/reindex → HOT/fillfactor redesign |

## Replication / Recovery

| Scenario | Mechanism | Diagnose | Fix / prevent |
|---|---|---|---|
| Slot retaining WAL | inactive consumer pins `restart_lsn` | retained-bytes per slot | restore consumer or drop + re-snapshot |
| Replica lag / failure | network / replay-blocked / IOPS-starved standby | sent/flush/replay LSN gaps, standby conflicts | cancel long standby queries, standby IOPS, feedback trade-offs — [Replication](./replication-internals.md) |
| Split-brain / failed promotion | dual primaries, divergent timelines | two writers, timeline forks | fencing (STONITH) via Patroni/operator; `pg_rewind` losers |
| Failed PITR / backup recovery | archive gap, wrong target, corrupt base | recovery logs, `pg_stat_archiver`, manifest verify | gap-free archiving, named restore points, drilled restores — [Backup](./backup-recovery-internals.md) |

## What Actually Happens Internally? (WAL-disk-full walkthrough)

1. Slot goes inactive Friday; `restart_lsn` freezes.
2. Weekend writes accumulate retained segments; monitoring watches disk-% (not retained-bytes) and stays green until 90%.
3. `pg_wal` hits 100% → `PANIC: could not write to file` → postmaster restarts; recovery can't proceed without WAL space → cluster down.
4. Recovery: emergency disk (symlink `pg_wal` out / extend volume), start, drop slot, checkpoint, verify. Prevention: retained-bytes alert at GB thresholds + slot-activity alert.

## Interview Questions

### Advanced

- One idle-in-transaction session, three pages of impact? — Bloat (xmin horizon), lock pile-up risk, wraparound-age advance.
- Slot vs archiver failure: same symptom, different fix? — Both fill `pg_wal`; slot needs consumer/drop decision, archiver needs command/storage repair — retained-bytes vs failed-count tells them apart.

## Key Takeaways

- Every scenario reduces to: name the pinned resource (XID horizon, WAL LSN, lock queue, disk mount), find its holder, release or bound it.
- Retained-WAL bytes, xmin age, and lock-queue depth deserve alerts equal to CPU/disk.
- Drills (failover, PITR, slot-loss) convert this file from reading into reflex.
