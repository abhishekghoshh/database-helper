# Data Definition Language (DDL)

## CREATE DATABASE

Creates a new, isolated database container on the server instance, optionally specifying encoding, collation, and owner.

```sql
CREATE DATABASE analytics
  WITH ENCODING = 'UTF8'
  OWNER = analytics_admin;
```

- Requires elevated (superuser/admin) privileges in most systems.
- Typically an infrequent, environment-setup-time operation rather than something application code does at runtime.

## CREATE SCHEMA

Creates a logical namespace within the current database to organize tables/views and scope permissions.

```sql
CREATE SCHEMA IF NOT EXISTS billing AUTHORIZATION billing_service;

CREATE TABLE billing.invoices (
    id     BIGINT PRIMARY KEY,
    amount NUMERIC(10, 2)
);
```

`IF NOT EXISTS` avoids an error if the schema is created redundantly (common in idempotent migration scripts).

## CREATE TABLE

Defines a new table's structure: columns, data types, constraints, and optionally storage parameters.

```sql
CREATE TABLE orders (
    id          BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(id),
    order_date  DATE NOT NULL DEFAULT CURRENT_DATE,
    status      VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    total       NUMERIC(10, 2) CHECK (total >= 0)
);

-- Create table from a query (structure + data copied, constraints usually NOT copied)
CREATE TABLE recent_orders AS
SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '30 days';
```

Column definitions combine a data type with optional constraints (`NOT NULL`, `DEFAULT`, `CHECK`, `REFERENCES`) inline, or constraints can be declared separately as table-level constraints (useful for composite/multi-column constraints).

## ALTER TABLE

Modifies an existing table's structure — adding/dropping/renaming columns, changing data types, adding/dropping constraints.

```sql
ALTER TABLE orders ADD COLUMN notes TEXT;
ALTER TABLE orders DROP COLUMN notes;
ALTER TABLE orders ALTER COLUMN total SET NOT NULL;         -- PostgreSQL
ALTER TABLE orders ALTER COLUMN total TYPE NUMERIC(12, 2);  -- PostgreSQL
ALTER TABLE orders RENAME COLUMN status TO order_status;
ALTER TABLE orders ADD CONSTRAINT chk_status CHECK (order_status IN ('PENDING','SHIPPED','CANCELLED'));
```

**Gotcha:** On large tables, some `ALTER TABLE` operations (e.g., changing a column type, adding a `NOT NULL` column without a default) can require rewriting the entire table and take an exclusive lock, causing downtime. Modern databases increasingly support online/non-blocking DDL for common cases (e.g., PostgreSQL adding a nullable column is instant metadata-only since v11+).

## DROP TABLE

Permanently removes a table and all its data, indexes, and dependent objects (depending on `CASCADE`/`RESTRICT`).

```sql
DROP TABLE IF EXISTS temp_import;
DROP TABLE orders CASCADE;  -- also drops dependent views/foreign keys referencing it
```

This operation is irreversible without a backup — unlike `DELETE`, there is no `WHERE` clause and no way to undo it via `ROLLBACK` once committed (and in many databases, DDL auto-commits).

## TRUNCATE TABLE

Quickly removes **all** rows from a table while keeping its structure intact, typically much faster than `DELETE` with no `WHERE` clause.

```sql
TRUNCATE TABLE session_logs;
TRUNCATE TABLE session_logs RESTART IDENTITY;  -- also resets auto-increment/sequence
```

| Aspect | `DELETE` (no WHERE) | `TRUNCATE` |
|---|---|---|
| Logging | Row-by-row (more WAL/undo) | Minimal, deallocates pages |
| Speed | Slower on large tables | Much faster |
| `WHERE` clause | Supported | Not supported (all-or-nothing) |
| Triggers | Row-level triggers fire | Typically do NOT fire (per-row triggers) |
| Rollback | Fully transactional | Transactional in PostgreSQL; auto-commits in some DBs (MySQL) |
| Resets identity/auto-increment | No (unless explicit) | Yes, can reset with `RESTART IDENTITY` |
| Foreign keys | Works even if referenced (row by row, checked) | Fails if referenced by other tables (unless cascaded) |

## RENAME TABLE

Changes a table's name without affecting its data, though dependent views/foreign keys referencing the old name may need updates depending on the database.

```sql
ALTER TABLE orders RENAME TO customer_orders;  -- PostgreSQL/Oracle syntax
RENAME TABLE orders TO customer_orders;        -- MySQL syntax
```

**Real-life scenario:** Renaming is often used during zero-downtime migrations — e.g., build a new table `orders_v2`, backfill data, then atomically rename `orders` → `orders_old` and `orders_v2` → `orders` within a transaction.

## COMMENT

Attaches descriptive metadata to a database object (table, column, etc.), useful for documentation visible via schema-inspection tools without needing external docs.

```sql
COMMENT ON TABLE orders IS 'Stores customer purchase orders';
COMMENT ON COLUMN orders.status IS 'One of: PENDING, SHIPPED, CANCELLED';
```

This is purely metadata — it has no effect on query behavior, but is valuable for team documentation and tools that auto-generate data dictionaries.

#### Interview Questions

1. **Why is `TRUNCATE` typically faster than `DELETE FROM table` with no `WHERE` clause?**
   `DELETE` removes rows one at a time, logging each row deletion (and firing row-level triggers), which is expensive for large tables. `TRUNCATE` deallocates entire data pages at once with minimal logging, making it much faster, though it usually can't be filtered with a `WHERE` clause and may not fire per-row triggers.
2. **Can `TRUNCATE` be rolled back inside a transaction?**
   It depends on the database. PostgreSQL and SQL Server support fully transactional `TRUNCATE` (rollback restores the data). MySQL's `TRUNCATE` implicitly commits the current transaction and cannot be rolled back because it's implemented as a drop-and-recreate of the table.
3. **What's a real risk of running `ALTER TABLE` to change a column type on a very large production table?**
   Many such changes require rewriting the entire table's storage (to convert existing values to the new type), which acquires an exclusive/access-exclusive lock for the duration — blocking reads and writes and potentially causing an outage. Mitigations include using online schema-change tools (e.g., `pt-online-schema-change`, `gh-ost` for MySQL) or database features supporting non-blocking changes.
4. **Why does `DROP TABLE ... CASCADE` need to be used carefully?**
   `CASCADE` automatically drops all dependent objects (foreign keys referencing the table, views built on it, etc.) along with the table itself. Without reviewing dependencies first, this can silently remove other objects the team didn't intend to lose, so it's best combined with first inspecting dependent objects or using `RESTRICT` (the safer default) to fail if dependents exist.
5. **What's the difference between DDL auto-commit behavior across databases, and why does it matter?**
   In MySQL and Oracle, DDL statements implicitly commit any open transaction, meaning you cannot wrap a `CREATE TABLE`/`ALTER TABLE` in a transaction and roll it back. PostgreSQL and SQL Server support transactional DDL, allowing schema changes to be rolled back alongside data changes — this matters for writing safe, reversible migration scripts.
6. **When would you use `RENAME TABLE` as part of a deployment strategy?**
   A common zero-downtime pattern is to build a new table with the desired schema, backfill/migrate data into it, then perform an atomic rename swap (old table renamed aside, new table renamed into place) — minimizing lock time compared to altering the live table in place.
