# PostgreSQL Logging and Debugging

## Overview

Logs are PostgreSQL's flight recorder: slow-query lines, lock waits, checkpoints, autovacuum, connections, and error codes. This file configures logging for diagnosability without drowning in volume, and shows the debugging workflow per subsystem.

See also:

- [Monitoring PostgreSQL Internals](./monitoring-postgres-internals.md)
- [Configuration Internals](./configuration-internals.md)
- [Locks and Concurrency Internals](./locks-concurrency-internals.md)

## Why This Matters

An incident without `log_min_duration_statement`, `log_lock_waits`, and `log_checkpoints` is archaeology. These three settings cost little and answer most questions.

## Architecture / `postgresql.conf` / Slow Queries / Locks / Connections / Autovacuum / Checkpoints / WAL

Production baseline:

```text
logging_collector = on
log_destination = 'csvlog'        # or 'jsonlog' (v15+) for structured shipping
log_min_duration_statement = 500  # ms; 0 = everything (dev only), -1 = off
log_lock_waits = on
log_checkpoints = on
log_autovacuum_min_duration = '10s'
log_connections = on              # high volume; sample or filter at collector
log_disconnections = on
log_temp_files = 0                # log all spills with size
log_replication_commands = on
```

- **Slow queries**: `log_min_duration_statement` + `auto_explain` (`auto_explain.log_analyze`, `log_buffers`, sampled via `auto_explain.sample_rate`) captures plans, not just text.
- **Locks**: `log_lock_waits` + `deadlock_timeout` (1 s) emits waiter/holder detail; deadlocks always log with the full wait graph.
- **Autovacuum/checkpoint/WAL**: duration + buffer counts lines correlate latency spikes to background work.
- **CSV/JSON logging**: machine-parseable (`log_filename`, rotation); ship to Loki/ELK with `application_name` + pid threading.

```sql
ALTER SYSTEM SET log_min_duration_statement = '500ms';
SELECT pg_reload_conf();
```

## Severity / Error Codes / Workflows

`DEBUG < LOG < NOTICE < WARNING < ERROR < FATAL < PANIC`. SQLSTATE codes (`23505` unique violation, `40P01` deadlock, `40001` serialization failure, `57P01` admin shutdown) drive alert routing and app retry logic — retry `40001`/`40P01`, never blindly retry `23505`.

Per-subsystem debugging: connections (`log_connections` + `pg_stat_activity` connect storms), locks (`log_lock_waits` + `pg_locks` queue query), autovacuum (`log_autovacuum_min_duration` + `pg_stat_progress_vacuum`), checkpoints (`log_checkpoints` + `pg_stat_bgwriter`), WAL (`pg_stat_wal` + archiver stats).

## Hands-on Experiment

```sql
SET log_min_duration_statement = '0';  -- session-level capture
SELECT pg_sleep(0.2);                  -- appears in log with duration
RESET log_min_duration_statement;
-- enable auto_explain in session (if preloaded): LOAD 'auto_explain'; SET auto_explain.log_analyze = on;
```

## Troubleshooting

### Symptom: logs too voluminous to find anything

Lower `log_min_duration_statement` selectively (per-role `ALTER ROLE reporter SET log_min_duration_statement = '100ms'`), route CSV/JSON to a collector with sampling, and keep `log_statement = 'none'` in production (full statement logging duplicates slow-query lines at 10× volume).

## Interview Questions

### Intermediate

- Which three log settings do you enable first on a new cluster? — Slow statements, lock waits, checkpoints — they localize 80% of incidents.
- When is `log_statement = 'all'` justified? — Almost never in production; use sampled `auto_explain` + slow-query threshold instead.

## Key Takeaways

- Log for diagnosis per incident class, not maximal verbosity.
- Structured logs (CSV/JSON) + `auto_explain` turn slow queries into solvable plans.
- Route SQLSTATE codes into retry/alert policy, not just dashboards.
