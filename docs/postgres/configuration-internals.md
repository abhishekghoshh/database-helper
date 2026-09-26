# Configuration Internals

## Overview

`postgresql.conf` + `ALTER SYSTEM` + per-database/role `SET` form a precedence stack, with restart-vs-reload semantics per parameter. This file explains the layers, the dangerous knobs by subsystem, and how to change production safely.

See also:

- [PostgreSQL Logging and Debugging](./postgresql-logging-debugging.md)
- [PostgreSQL Memory Architecture](./postgresql-memory-architecture.md)
- [Monitoring PostgreSQL Internals](./monitoring-postgres-internals.md)

## Why This Matters

Most PostgreSQL outages from "tuning" come from precedence surprises (`ALTER SYSTEM` overriding the file edit) or restart-required changes applied without restart. Know the stack and the context column.

## Files / `ALTER SYSTEM` / Reload vs Restart / Session / Transaction / Precedence / `pg_settings`

```text
defaults → postgresql.conf → conf.d/*.conf → postgresql.auto.conf (ALTER SYSTEM)
  → per-database → per-role → per-session SET → per-transaction SET LOCAL
  (later wins; command line -c/-o beats all files)
```

```sql
SELECT name, setting, unit, context, source, sourcefile
FROM pg_settings WHERE source <> 'default' ORDER BY name;
-- context: internal | postmaster(restart) | sighup(reload) | superuser | user
```

- **Reload** (`pg_reload_conf()`): `sighup` parameters (most logging, vacuum costs, timeouts).
- **Restart**: `postmaster` parameters (`shared_buffers`, `max_connections`, `wal_level`, `shared_preload_libraries`, ports).
- `ALTER SYSTEM` writes `postgresql.auto.conf` — it *overrides* hand-edited conf; always inspect `source` when a change "doesn't take".

## Knob Map by Subsystem

| Area | Key parameters | Change class |
|---|---|---|
| Memory | `shared_buffers`, `work_mem`, `maintenance_work_mem`, `effective_cache_size` | restart / reload(user) — see [Memory](./postgresql-memory-architecture.md) |
| WAL | `wal_level`, `synchronous_commit`, `wal_compression`, `max_wal_size`, `archive_mode` | mixed; `wal_level` needs restart |
| Connections | `max_connections`, `superuser_reserved_connections`, timeouts, keepalives | restart for max; reload for timeouts |
| Autovacuum | thresholds, scale factors, cost limits, workers | reload — safe to iterate live |
| Planner | `random_page_cost`, `effective_cache_size`, `*_cost`, `jit` | reload; session-testable via `SET` |
| Parallelism | `max_worker_processes` (restart), `max_parallel_workers*` (reload) | split contexts — check `pg_settings` |

Safe-change protocol: stage on a replica/canary → `ALTER SYSTEM` + reload → watch `pg_settings.source` + metrics → commit to config management (Ansible/Terraform/operator CRD) so the DB isn't the source of truth.

## Hands-on Experiment

```sql
SHOW work_mem;  -- session value
SET work_mem = '64MB'; SHOW work_mem;          -- session override
BEGIN; SET LOCAL work_mem = '256MB'; SHOW work_mem; COMMIT;
SHOW work_mem;  -- back to session
SELECT name, context, source FROM pg_settings WHERE name IN ('shared_buffers','work_mem','max_connections');
```

## Interview Questions

### Intermediate

- Why didn't my `postgresql.conf` edit take effect? — `postgresql.auto.conf` (ALTER SYSTEM) overrides it, or the parameter needs restart/reload you didn't perform. `pg_settings.source` tells you.
- Session vs transaction settings? — `SET` lasts the session; `SET LOCAL` lasts the transaction — used for per-report `work_mem` boosts without global risk.

## Key Takeaways

- Read `pg_settings` (context + source) before changing anything.
- Reload-safe knobs (vacuum, timeouts, planner costs) iterate live; restart knobs plan with failover.
- Config management owns the files; the database is the runtime, not the repo.
