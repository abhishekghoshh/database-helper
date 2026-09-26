# Backup and Recovery Internals

## Overview

Physical base backup + continuous WAL archiving = point-in-time recovery to any LSN/timestamp. Logical dumps (`pg_dump`) serve migration and selective restore, not RPO/RTO. This file explains the backup chain, recovery targets, verification, and DR math.

See also:

- [WAL: Write-Ahead Logging](./wal.md)
- [Crash Recovery Internals](./crash-recovery-internals.md)
- [Replication Internals](./replication-internals.md)

## Why This Matters

Backups that have never been restored are hopes, not backups. PITR mechanics determine whether "restore to 5 min before the bad deploy" is a command or a fantasy.

## Physical vs Logical / `pg_dump` / `pg_basebackup` / Filesystem / Archiving / PITR

```mermaid
flowchart LR
    Base[Base backup: pg_basebackup] --> WALs[WAL archive chain]
    WALs --> Target[Recovery target: LSN / time / xid / name]
    Target --> DB[Restored cluster]
```

- **Physical** (`pg_basebackup -Ft -z -D`, or `pgBackRest`/`Barman` with parallel+compress+encrypt): whole-cluster byte copy + `backup_label` with start LSN. Fast, complete, version-coupled.
- **Logical** (`pg_dump`/`pg_restore`, `COPY`): per-database SQL/custom-format; portable across versions, slow at scale, no PITR.
- **Continuous archiving** (`archive_mode = on`, `archive_command = 'test ! -f /arc/%f && cp %p /arc/%f'`): every completed segment preserved. Miss one segment → PITR gap.
- **PITR** (`recovery_target_time/lsn/xid/name`, `restore_command = 'cp /arc/%f %p'`): replay base + WAL to the target, then `recovery_target_action = promote/pause/shutdown`. Named restore points (`pg_create_restore_point('deploy')`) beat timestamps for deploy rollbacks.

## Consistency / Verification / DR / RPO / RTO / Corruption

- **Consistency**: base backups are fuzzy (taken while running) + WAL makes them consistent — `pg_verifybackup` checks manifest checksums (v13+).
- **Verification**: automated restore to a sandbox + `amcheck` + app-level row counts, on schedule. Alert on `pg_stat_archiver.failed_count` and archive age.
- **RPO/RTO**: RPO = archive lag (seconds with streaming archive like pgBackRest async); RTO = base size/bandwidth + WAL volume to replay. Size both from measured restores, not vendor claims.
- **Corruption**: checksum failures (`--data-checksums`) surface at restore/replay; keep multiple base generations + off-site archive copies.

```sql
SELECT * FROM pg_stat_archiver;  -- archived_count vs failed_count
SELECT pg_create_restore_point('pre_migration');
```

## Hands-on Experiment

1. `pg_basebackup -D /tmp/bak -Ft -z -P`, note start LSN.
2. Write rows, `SELECT pg_switch_wal();`, archive segments.
3. Restore to a scratch `PGDATA`, set `restore_command`, `recovery_target_time`, boot, verify rows present/absent per target.

## Troubleshooting

### Symptom: `FATAL: requested WAL segment has already been removed`

Archive gap or retention purge. **Fix:** rebuild from a newer base; extend retention; never let archive storage share fate with `pg_wal` disk.

## Interview Questions

### Intermediate

- Why can't `pg_dump` give you PITR? — It's a logical snapshot at dump time with no WAL chain to roll forward through.
- Base + WAL vs filesystem snapshot? — Snapshots need crash-recovery replay too (fuzzy without `pg_start_backup` coordination); basebackup + archive is the supported portable chain.

### Advanced

- How do you prove RPO/RTO, not assert them? — Timed restore drills measuring archive lag at incident start and wall-clock to promoted + verified traffic.

## Key Takeaways

- Physical + archive = time travel. Logical = portability. Run both, drill the former.
- `pg_stat_archiver` + restore drills are the backup monitoring that matters.
- Restore points beat timestamps for human-driven rollbacks.
