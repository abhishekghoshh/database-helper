# Advanced PostgreSQL Features

## Overview

RLS, generated/identity columns, rich types (range, multirange, arrays, JSONB), full-text search, LISTEN/NOTIFY, advisory locks, event triggers, exclusion constraints, and matviews — the features that make PostgreSQL a platform. Internals-first notes per feature with planner/lock implications.

See also:

- [PostgreSQL as More Than a Database](./postgres-as-platform.md)
- [PostgreSQL Security Internals](./postgresql-security-internals.md)
- [Index Internals](./index-internals.md)

## Feature Notes

- **Row-Level Security** (`CREATE POLICY`, `USING`/`WITH CHECK`): predicates injected at rewrite; planner can't always push them optimally — verify plans per role. `BYPASSRLS` for owners; table-owner bypass is a footgun in multi-tenant designs.
- **Security barrier views**: prevent predicate-pushdown leaks in RLS/view stacks (`security_barrier`).
- **Generated columns** (`GENERATED ALWAYS AS (...) STORED`): computed at write, WAL-logged, indexable — materialized-expression trade (write cost vs read speed).
- **Identity columns** (`GENERATED ... AS IDENTITY`): sequence-backed, SQL-standard successor to `SERIAL`.
- **Domains / composite / enum / range / multirange / arrays / JSONB**: typed constraints with GiST/GIN support (range exclusion, array containment). Multirange aggregates disjoint ranges — scheduling/availability modeling without app code.
- **Full-text search** (`tsvector`, `tsquery`, GIN, `ts_rank`): indexable lexeme search with dictionaries/stop-words per language.
- **`LISTEN/NOTIFY`** (8000 B payload, transient, coalesced): signaling, not messaging — see [platform](./postgres-as-platform.md).
- **Advisory locks**: app mutexes; no MVCC interaction; crash releases with session.
- **Event triggers**: DDL hooks (audit/migration guardrails) firing on `ddl_command_end`.
- **Logical replication / matviews** (`REFRESH ... CONCURRENTLY` with unique index): covered in [replication](./replication-internals.md) / [CDC](./logical-decoding-cdc.md).
- **Exclusion constraints** (`EXCLUDE USING gist`): generalized uniqueness (no-overlap bookings) enforced via index — concurrent inserts serialize on the predicate; design hot paths accordingly.
- **Deferrable constraints**: checked at commit (`DEFERRABLE INITIALLY DEFERRED`) — enables cyclic FK loads, costs holding checks to commit.
- **Partitioning / FDW**: see dedicated files.

```sql
CREATE POLICY tenant_iso ON orders USING (tenant_id = current_setting('app.tenant')::int);
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
```

## Hands-on Experiment

Enable RLS on a test table, `SET app.tenant`, and `EXPLAIN` the same query as different tenants — observe injected quals and plan changes. Add an exclusion constraint on a booking table and collide two concurrent inserts to feel the predicate-lock serialization.

## Interview Questions

### Intermediate

- RLS vs application WHERE clauses? — Enforcement in the database survives every client/ORM/reporting tool; misplanned policies cost performance, so EXPLAIN per role.
- Stored generated vs view expression? — Generated pays at write (WAL + storage) for indexed/fast reads; view pays per read.

## Key Takeaways

- Features compose (RLS + partitioning + logical replication) but each adds planner/lock surface — verify combined plans.
- Prefer database enforcement (constraints, RLS, exclusion) for invariants; app code for presentation.
