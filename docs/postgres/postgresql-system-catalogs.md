# Important PostgreSQL System Catalogs

## Overview

PostgreSQL's catalogs (`pg_class`, `pg_attribute`, `pg_index`, …) are the metadata database the server itself queries for planning, execution, and DDL. Fluency here turns "mystery behavior" into catalog lookups. This file maps the essential catalogs to their runtime uses.

See also:

- [PostgreSQL Source Code Architecture](./postgresql-source-code-architecture.md) (`catalog/` + relcache/catcache)
- [Monitoring PostgreSQL Internals](./monitoring-postgres-internals.md)
- [PostgreSQL Statistics](./postgresql-statistics.md) (`pg_statistic`)

## Why This Matters

Every plan, permission check, partition route, and replication decision reads catalogs (cached in relcache/catcache with sinval invalidation). Reading them directly answers: what exists, how it's defined, what the planner sees.

## Core Catalogs

| Catalog | One row per … | Key columns / use |
|---|---|---|
| `pg_class` | relation (table/index/sequence/view/matview/partition/TOAST) | `relkind`, `relfilenode`, `relpages/reltuples` (planner size), `relfrozenxid`, `relpersistence` |
| `pg_attribute` | column | `attnum`, `atttypid`, `attnotnull`, `attgenerated`, dropped-column tombstones |
| `pg_namespace` | schema | `search_path` resolution, per-schema grants |
| `pg_database` | database | `datfrozenxid` (wraparound age), `datconnlimit`, encoding/collation |
| `pg_tablespace` | tablespace | `spclocation` mapping to devices |
| `pg_index` | index | `indkey`, `indisvalid/ready/live`, `indpred` (partial), `indclass` |
| `pg_constraint` | constraint | `contype` (p/f/u/c/x…), deferrability, FK actions |
| `pg_proc` | function/procedure | `prokind`, volatility (`i/s/v`), `prosecdef`, args/returns |
| `pg_type` | data type | base/composite/enum/range/domain wiring |
| `pg_roles` + `pg_auth_members` | roles + membership | login/inherit/connection-limit, grant graphs |
| `pg_statistic` (+`pg_stats` view) | planner stats per column | histograms, MCVs — see [Statistics](./postgresql-statistics.md) |
| `pg_settings` | GUC | `context`, `source`, restart-vs-reload — see [Configuration](./configuration-internals.md) |
| `pg_locks` / `pg_stat_activity` | runtime locks / sessions | live state, not persisted — see [Monitoring](./monitoring-postgres-internals.md) |
| `pg_replication_slots` | slots | `restart_lsn`, active — WAL retention accounting |
| `pg_publication` / `pg_subscription` (+`_tables`) | logical replication config | what replicates where |
| `pg_trigger` | triggers | `tgenabled` (replica/always firing), timing/level |

## Catalogs as the Metadata Database

```sql
-- what is this table really? (toast, size, frozen age, persistence)
SELECT c.relname, c.relkind, c.relpersistence, age(c.relfrozenxid),
       pg_size_pretty(pg_total_relation_size(c.oid)),
       t.spcname AS tablespace
FROM pg_class c LEFT JOIN pg_tablespace t ON t.oid = c.reltablespace
WHERE c.relname = 'orders';
-- index health: validity + predicate + columns
SELECT i.relname, x.indisvalid, x.indisready, pg_get_indexdef(x.indexrelid)
FROM pg_index x JOIN pg_class i ON i.oid = x.indexrelid
WHERE x.indrelid = 'orders'::regclass;
-- FK graph around a table
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='orders'::regclass;
```

Catalog caches make this cheap: backends cache descriptors (relcache) and rows (catcache), invalidated via sinval messages on DDL — which is why massive DDL churn shows up as cache-invalidation overhead, and why `pg_class.reltuples` can lag (it's vacuum/analyze-maintained estimates, not counts).

## Interview Questions

### Intermediate

- `pg_class` vs filesystem: which is truth for size? — Filesystem holds pages; `relpages/reltuples` are planner estimates maintained by vacuum/analyze — fresh enough for plans, never for billing.
- How do you find an `INVALID` index and what does it mean? — `pg_index.indisvalid = false`: failed `CREATE INDEX CONCURRENTLY` leftover — queries ignore it, writes may still maintain it; drop and rebuild.

## Key Takeaways

- Catalogs are queryable internals: size, frozen age, validity, constraints, stats — all one SELECT away.
- Caches (relcache/catcache + sinval) make catalog reads cheap and DDL-churn visible.
- Join catalogs with stats views (`pg_stat_*`) for the full object + activity picture.
