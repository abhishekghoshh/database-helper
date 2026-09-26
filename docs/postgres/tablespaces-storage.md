# Tablespaces and Storage

## Overview

Tablespaces map relations and WAL to filesystem locations, enabling I/O isolation across devices. This short file covers placement strategy, temp-file control, failure modes, and hardware considerations.

See also:

- [PostgreSQL Storage Architecture](./postgresql-storage-architecture.md)
- [Temporary Files and Disk Usage](./temporary-files-disk-usage.md)
- [Backup and Recovery Internals](./backup-recovery-internals.md)

## Tablespaces / Placement / I/O Isolation

```sql
CREATE TABLESPACE fast_ssd LOCATION '/mnt/ssd/pg';
CREATE TABLE hot (id bigserial primary key, v int) TABLESPACE fast_ssd;
ALTER TABLE hot SET TABLESPACE slow_hdd;  -- rewrite, takes AccessExclusive
```

Strategy: `pg_wal` on dedicated low-latency devices (fsync isolation), hot indexes/tables on SSD, cold archives on cheap storage, temp files on ephemeral fast disk. I/O isolation means checkpoint flushes and WAL fsyncs don't contend on the same queue — measurable p99 wins on write-heavy hosts.

## SSD vs HDD / WAL vs Data / Temp Storage / `temp_tablespaces`

- **SSD**: random I/O (index scans, vacuum, replay) transforms; `random_page_cost` should reflect it (1.1–2).
- **WAL vs data**: separate devices so sequential WAL fsync latency never queues behind random heap reads.
- **`temp_tablespaces`**: spill/sort/hash temp files to fast ephemeral storage; isolates runaway-query I/O from data devices and simplifies capacity planning.

## Failure Scenarios / Bottlenecks / Filesystem Requirements

A lost tablespace = lost relations (per-tablespace `PG_VERSION` + files; no graceful degraded mode). Backups must include all tablespace paths (`pg_basebackup` handles mapping; verify restores remap correctly). Filesystem needs: reliable fsync (no lying controllers — test with `pg_test_fsync`), checksums enabled (`initdb --data-checksums`), and monitoring per mount (WAL-full and data-full are different outages with different runbooks).

## Interview Questions

### Intermediate

- Why separate WAL and data devices? — WAL fsync latency is on the commit path; sharing queues with random heap I/O makes commits wait on reads.
- What happens when a tablespace disk dies? — Relations there are unavailable; recovery is from backup + WAL replay, not from the surviving tablespaces.

## Key Takeaways

- Tablespaces are an I/O-isolation tool, not a management convenience.
- WAL device latency is commit latency — provision it first.
- Every extra mount is an extra failure domain: back it up and monitor it independently.
