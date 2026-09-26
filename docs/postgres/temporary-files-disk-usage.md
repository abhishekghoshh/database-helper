# Temporary Files and Disk Usage

## Overview

Sorts, hashes, and bitmaps exceeding `work_mem` spill to `pgsql_tmp` files; temp tables live in per-session schemas. Spill is correctness-preserving but I/O-expensive, and unbounded spill fills disks. This file explains the spill path, monitoring, and control.

See also:

- [PostgreSQL Memory Architecture](./postgresql-memory-architecture.md)
- [Query Execution Internals](./query-execution-internals.md)
- [Configuration Internals](./configuration-internals.md)

## Temp Files / Tables / Sort-Hash Spill / `work_mem` / Creation / Logging

Executor nodes (sort, hashjoin, hashaggregate, bitmap) buffer in `work_mem`; overflow writes temp files under `base/pgsql_tmp/` (or `temp_tablespaces`), merged/streamed back as needed. `log_temp_files = 0` logs every spill with size — the cheapest query-tuning telemetry available:

```text
LOG: temporary file: path "base/pgsql_tmp/pgsql_tmp1234.0", size 1.2 GB
```

Temp tables (`CREATE TEMP TABLE`) are session-private relations (visible in `pg_class` with `relpersistence = 't'`), auto-dropped at session end; heavy temp-table users should raise `temp_buffers` per-session.

## Disk Pressure / Memory-vs-Spill / Monitoring

```text
bigger work_mem → less spill, more OOM risk
smaller work_mem → more spill, more temp I/O, slower analytics
```

Monitor: `log_temp_files` volume, `pg_stat_database.temp_files/temp_bytes` growth, temp-tablespace disk rate. A sudden spill spike after a deploy = plan regression or statistics rot, not a memory shortage.

```sql
SELECT datname, temp_files, pg_size_pretty(temp_bytes) FROM pg_stat_database ORDER BY temp_bytes DESC;
```

## Hands-on Experiment

```sql
SET work_mem = '1MB'; SET log_temp_files = 0;
SELECT * FROM (SELECT generate_series(1,3000000) g) s ORDER BY g;  -- spills; check logs
RESET work_mem;  -- re-run: quicksort in memory, no temp file
```

## Troubleshooting

### Symptom: temp disk fills overnight

Runaway cartesian/duplicate-sensitive query or `work_mem` slashed globally. **Diagnose:** `log_temp_files` top sizes, `pg_stat_activity` long runners. **Fix:** kill + fix the query (join condition, missing predicate), raise per-role `work_mem` for the legitimate analytics role, cap with `statement_timeout`.

## Interview Questions

### Intermediate

- Spill vs OOM: which is safer and why? — Spill: bounded slowdown, query still completes. OOM: backend killed, transaction lost, possibly cascading.
- What does `log_temp_files = 0` cost? — A log line per spill file; negligible vs the diagnostic value.

## Key Takeaways

- Spill keeps queries correct under memory pressure — treat spill volume as a tuning signal, not an error.
- Size `work_mem` from measured spill at p99 concurrency, per role where possible.
- Temp-tablespace isolation turns runaway analytics into a contained incident.
