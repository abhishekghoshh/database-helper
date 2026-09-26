# PostgreSQL Extensions

## Overview

Extensions (`CREATE EXTENSION`) package SQL objects + optional C libraries with versioned upgrade scripts, turning PostgreSQL into an extensible platform (PostGIS, pg_stat_statements, pgvector, TimescaleDB). This file explains the packaging, lifecycle, and security model.

See also:

- [Foreign Data Wrappers](./foreign-data-wrappers.md)
- [Monitoring PostgreSQL Internals](./monitoring-postgres-internals.md) (pg_stat_statements)
- [PostgreSQL Source Code Architecture](./postgresql-source-code-architecture.md) (extension APIs)

## Why This Matters

Production PostgreSQL *is* core + extensions. Understanding control files, upgrade paths, and `shared_preload_libraries` mechanics prevents "extension works on primary, breaks restore/replica" incidents.

## Architecture / `CREATE EXTENSION` / Control Files / Scripts / Versioning / Upgrades

An extension = `<name>.control` (metadata: version, `shared_preload_libraries` needs, relocatable?) + versioned SQL scripts (`<name>--1.0.sql`, `<name>--1.0--2.0.sql` upgrade deltas) installed under `SHAREDIR/extension/`:

```sql
CREATE EXTENSION pg_stat_statements;              -- runs 1.x install script
ALTER EXTENSION pg_stat_statements UPDATE TO '1.10';  -- runs upgrade delta chain
SELECT * FROM pg_extension;  SELECT * FROM pg_available_extensions;
```

- C-language extensions load `.so` from `LIBDIR`; ones needing postmaster-start hooks (pg_stat_statements counters, `pg_cron` scheduler, Citus) require `shared_preload_libraries` + **restart**.
- Upgrades run in a transaction applying sequential deltas — test on a clone; a failed mid-chain upgrade leaves the extension version half-advanced (recover via backup or manual script replay).

## PostGIS / pg_stat_statements / pgcrypto / postgres_fdw / Custom / Security / Lifecycle

| Extension | What it adds | Operational note |
|---|---|---|
| PostGIS | geometry/geography types, GiST indexes, 1000+ functions | heavy install; upgrades need `ALTER EXTENSION ... UPDATE` + sometimes `SELECT postgis_extensions_upgrade()` |
| pg_stat_statements | normalized query stats (`queryid`, calls, mean time) | needs `shared_preload_libraries` + restart; the observability baseline |
| pgcrypto | `gen_random_uuid()`, pgp/symmetric crypto | prefer app-layer crypto for keys; pgcrypto for hashing (`crypt()`/bcrypt) |
| postgres_fdw | remote PG tables | see [FDW](./foreign-data-wrappers.md); pushdown determines viability |
| Custom (C/Rust/pgxs) | new types, AMs, bgworkers | runs *inside backends* — a crash takes the session; fuzz + stage on replicas first |

**Security**: extensions run as the installing superuser at `CREATE` time; `search_path` attacks via extension functions are real — pin `search_path`, review `SECURITY DEFINER` functions, and treat marketplace extensions like dependencies (pin versions, audit updates).

## Hands-on Experiment

```sql
CREATE EXTENSION pg_stat_statements;
SELECT query, calls, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 5;
SHOW shared_preload_libraries;  -- confirm preload requirement
```

## Interview Questions

### Intermediate

- Why do some extensions need a restart? — They hook postmaster-startup shared memory (stats, schedulers) that only initializes at boot.
- What breaks when primary and replica extension versions diverge? — WAL replay of extension-logged changes (e.g., PostGIS index AM records) can fail; keep versions identical via automation.

## Key Takeaways

- Extensions are versioned code + schema with transactional upgrades — manage them like migrations.
- Preload extensions need restart planning; all C extensions need crash-domain respect.
- pg_stat_statements first, everything else by measured need.
