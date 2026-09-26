# Foreign Data Wrappers

## Overview

FDWs expose remote systems (PostgreSQL, files, S3, Chánh APIs) as local tables with pushdown optimization. `postgres_fdw` enables federated queries and online migration patterns. This file explains the architecture, pushdown economics, and performance cliffs.

See also:

- [PostgreSQL Extensions](./postgresql-extensions.md)
- [Query Execution Internals](./query-execution-internals.md)

## Why This Matters

FDW queries look local but execute remotely — without pushdown understanding, a "simple join" fetches entire remote tables. Know what ships where before using FDWs past prototyping.

## Architecture / Servers / Tables / postgres_fdw / Pushdown / Remote Txns

```sql
CREATE EXTENSION postgres_fdw;
CREATE SERVER remote FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'db2', dbname 'app');
CREATE USER MAPPING FOR app SERVER remote OPTIONS (user 'app', password '...');
CREATE FOREIGN TABLE remote_orders (...) SERVER remote OPTIONS (schema_name 'public', table_name 'orders');
```

- **Pushdown** (`src/backend/foreign/` + fdw callbacks): `WHERE` clauses, joins (v14+ full outer/cross improvements), aggregates, `LIMIT` ship remotely when the FDW proves semantic equivalence. `EXPLAIN (VERBOSE)` shows `Remote SQL:` — the shipped fragment. Non-pushable expressions (custom functions, collations) force local fetch + filter.
- **Remote transactions**: each foreign scan opens a remote txn; 2PC across servers is *not* coordinated — cross-server writes are best-effort consistent, not atomic.

## Performance / Federation / Cross-DB Queries

Cost model: remote startup + row-transfer dominates; one selective pushed-down query is fine, join-heavy analytics across servers is not. Use FDWs for: migrations (dual-read cutover), rare admin joins, archiving to cheap stores. Avoid for: hot-path joins, high-frequency OLTP fan-out, anything needing cross-server transactions.

```sql
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM remote_orders WHERE status='shipped' LIMIT 10;
-- check Remote SQL includes WHERE + LIMIT; if not, add indexes remotely or restructure
```

## Interview Questions

### Intermediate

- What determines whether a filter runs remotely? — FDW deparse proof: built-in ops on remote columns push; volatile/custom functions don't.
- Why no atomic cross-server writes? — Independent remote transactions without 2PC coordination; failure mid-write leaves partial effects.

## Key Takeaways

- `Remote SQL` in EXPLAIN is the whole performance story — read it before shipping FDW queries.
- Federate reads for migrations and admin; don't build hot paths on cross-server joins.
