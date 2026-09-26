# Data Manipulation Language (DML)

## INSERT

Adds new row(s) to a table. Columns not listed take their `DEFAULT` value (or `NULL` if no default and the column is nullable).

```sql
INSERT INTO employees (id, first_name, last_name, hire_date)
VALUES (1, 'Alice', 'Nguyen', '2024-01-15');

-- Omitting columns with defaults
INSERT INTO orders (id, customer_id) VALUES (100, 42);  -- status defaults to 'PENDING'
```

## INSERT Multiple Rows

A single `INSERT` statement can supply multiple value lists, which is far more efficient than issuing one `INSERT` per row (fewer round-trips, often a single transaction/log entry).

```sql
INSERT INTO employees (id, first_name, last_name) VALUES
    (2, 'Bob', 'Smith'),
    (3, 'Carla', 'Diaz'),
    (4, 'Dan', 'Lee');
```

**Real-life scenario:** Bulk-loading a CSV import of thousands of rows should batch inserts (e.g., 500-1000 rows per statement) rather than one-row-at-a-time inserts, cutting import time dramatically by reducing network round-trips and per-statement overhead.

## INSERT ... SELECT

Inserts rows produced by a `SELECT` query, useful for copying/migrating data between tables without pulling it into the application first.

```sql
INSERT INTO archived_orders (id, customer_id, order_date, total)
SELECT id, customer_id, order_date, total
FROM orders
WHERE order_date < CURRENT_DATE - INTERVAL '1 year';
```

This pattern is common for archiving, ETL staging, and building denormalized reporting tables directly inside the database engine.

## UPDATE

Modifies existing rows matching a condition. Omitting the `WHERE` clause updates **every** row in the table — one of the most common and costly SQL mistakes.

```sql
UPDATE employees
SET salary = salary * 1.05
WHERE department = 'Engineering';

-- Update using values from another table
UPDATE orders o
SET total = oi.computed_total
FROM (SELECT order_id, SUM(price * quantity) AS computed_total
      FROM order_items GROUP BY order_id) oi
WHERE o.id = oi.order_id;
```

**Safety tip:** Always run the equivalent `SELECT ... WHERE ...` first to verify which rows will be affected before running the `UPDATE`/`DELETE`, especially in production.

## DELETE

Removes rows matching a condition; like `UPDATE`, omitting `WHERE` deletes every row (but unlike `TRUNCATE`, it's row-by-row, transactional, and fires triggers).

```sql
DELETE FROM sessions WHERE expires_at < now();

-- Delete based on a join/subquery
DELETE FROM order_items
WHERE order_id IN (SELECT id FROM orders WHERE status = 'CANCELLED');
```

## MERGE / UPSERT (Database Specific)

"Upsert" means insert a row if it doesn't exist, or update it if it does — a common need for idempotent data synchronization (e.g., syncing an external feed).

```sql
-- PostgreSQL / SQLite: INSERT ... ON CONFLICT
INSERT INTO product_inventory (product_id, quantity)
VALUES (101, 50)
ON CONFLICT (product_id)
DO UPDATE SET quantity = product_inventory.quantity + EXCLUDED.quantity;

-- MySQL: INSERT ... ON DUPLICATE KEY UPDATE
INSERT INTO product_inventory (product_id, quantity)
VALUES (101, 50)
ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity);

-- SQL Server / Oracle: MERGE
MERGE INTO product_inventory AS target
USING (SELECT 101 AS product_id, 50 AS quantity) AS src
ON target.product_id = src.product_id
WHEN MATCHED THEN UPDATE SET quantity = target.quantity + src.quantity
WHEN NOT MATCHED THEN INSERT (product_id, quantity) VALUES (src.product_id, src.quantity);
```

**Real-life scenario:** A nightly job syncing product prices from a supplier's feed can use upsert so the same script works whether a product already exists locally or is brand new, without needing a separate existence check and conditional branch in application code.

## RETURNING Clause (PostgreSQL)

Returns values from rows affected by `INSERT`/`UPDATE`/`DELETE`, avoiding a separate round-trip `SELECT` to fetch generated values (like an auto-generated ID or a computed default).

```sql
INSERT INTO orders (customer_id, total)
VALUES (42, 99.99)
RETURNING id, created_at;

DELETE FROM sessions WHERE expires_at < now() RETURNING id, user_id;
```

This is PostgreSQL/Oracle-specific (Oracle uses `RETURNING ... INTO`); MySQL and SQL Server lack a direct equivalent (SQL Server offers `OUTPUT` instead, with similar purpose).

#### Interview Questions

1. **What happens if you run `UPDATE employees SET salary = 0` without a `WHERE` clause?**
   Every row in the table is updated — all employees' salaries become `0`. This is one of the most common production incidents; the safe practice is to first run the equivalent `SELECT` with the same `WHERE` condition to confirm the target rows, and to use transactions so the mistake can be rolled back if not yet committed.
2. **Why is a single multi-row `INSERT` generally faster than many single-row `INSERT` statements?**
   Each statement incurs network round-trip latency, parsing/planning overhead, and (depending on configuration) a transaction commit. Batching many rows into one statement (or wrapping many statements in one transaction) amortizes this overhead across all rows, which can be an order of magnitude faster for bulk loads.
3. **What does "upsert" mean, and how does it differ across PostgreSQL, MySQL, and SQL Server?**
   Upsert inserts a new row or updates an existing one in a single atomic statement, avoiding a race condition where a check-then-insert pattern in application code sees a row as missing and then fails on a duplicate-key error from a concurrent insert. PostgreSQL uses `INSERT ... ON CONFLICT DO UPDATE`, MySQL uses `INSERT ... ON DUPLICATE KEY UPDATE`, and SQL Server/Oracle use the more general-purpose `MERGE` statement.
4. **What is the purpose of the `RETURNING` clause, and what problem does it solve?**
   `RETURNING` lets an `INSERT`/`UPDATE`/`DELETE` statement return column values (like an auto-generated primary key or a default timestamp) directly in the same round-trip, avoiding a separate `SELECT` query afterward that could theoretically see different data due to a race condition.
5. **How does `DELETE` differ from `TRUNATE` in terms of triggers and transactional rollback?**
   `DELETE` processes rows individually, firing any row-level triggers and fully participating in the surrounding transaction (a `ROLLBACK` undoes it). `TRUNCATE` deallocates data pages directly, typically does not fire row-level triggers, and in some databases (MySQL) auto-commits, meaning it cannot be rolled back.
6. **Why would you use `INSERT ... SELECT` instead of reading rows into the application and inserting them back?**
   Doing the copy entirely within the database avoids pulling potentially large result sets across the network into the application and back, which is both slower and more memory-intensive. It also runs atomically as a single statement, reducing the risk of partial failures compared to a multi-step read-then-write client-side process.
