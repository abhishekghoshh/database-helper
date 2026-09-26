# Basic Queries

## SELECT

The `SELECT` statement retrieves data from one or more tables. It's the most commonly used SQL statement and forms the basis of nearly every read operation.

```sql
SELECT id, first_name, last_name FROM employees;

-- Select all columns (avoid in production application code — brittle to schema changes)
SELECT * FROM employees;

-- Computed/expression columns
SELECT first_name || ' ' || last_name AS full_name, salary * 12 AS annual_salary
FROM employees;
```

**Best practice:** Avoid `SELECT *` in application code — it fetches unnecessary columns (wasting bandwidth), breaks if columns are added/removed/reordered, and can silently change behavior when relied upon positionally.

## DISTINCT

Removes duplicate rows from the result set, comparing across all selected columns as a combined unit.

```sql
SELECT DISTINCT department FROM employees;

-- DISTINCT applies to the whole row/column combination, not each column independently
SELECT DISTINCT department, job_title FROM employees;
```

**Gotcha:** `DISTINCT` requires the database to compare/sort or hash all result rows, which can be expensive on large result sets. Often an equivalent `GROUP BY` achieves the same deduplication and may be optimized similarly, but `EXISTS`-based rewrites can sometimes outperform both when checking for presence.

## WHERE

Filters rows before grouping/aggregation, based on a boolean condition. Only rows for which the condition evaluates to `TRUE` are kept (rows evaluating to `FALSE` or `UNKNOWN`/`NULL` are excluded).

```sql
SELECT * FROM orders WHERE status = 'PENDING' AND total > 100;
```

## ORDER BY

Sorts the final result set by one or more columns/expressions, ascending (`ASC`, default) or descending (`DESC`).

```sql
SELECT name, salary FROM employees ORDER BY salary DESC, name ASC;

-- Sort by column position (works but discouraged — brittle to SELECT list changes)
SELECT name, salary FROM employees ORDER BY 2 DESC;

-- NULLS handling (PostgreSQL/Oracle)
SELECT name, commission FROM employees ORDER BY commission DESC NULLS LAST;
```

Without an explicit `ORDER BY`, SQL makes **no guarantee** about row order — relying on "apparent" default ordering (e.g., insertion order) is a common bug source since the optimizer is free to return rows in any order it finds efficient.

## LIMIT

Restricts the number of rows returned by a query — commonly used for pagination or fetching "top N" results.

```sql
-- PostgreSQL / MySQL
SELECT * FROM products ORDER BY price DESC LIMIT 10;
```

`LIMIT` is not part of the ANSI standard (it's a widely supported PostgreSQL/MySQL/SQLite extension); SQL Server uses `TOP`, and the standard approach is `FETCH FIRST`/`OFFSET ... FETCH`.

## OFFSET

Skips a specified number of rows before starting to return rows, typically combined with `LIMIT`/`FETCH` for pagination.

```sql
-- Page 3 of 10-row pages (skip first 20 rows)
SELECT * FROM products ORDER BY id LIMIT 10 OFFSET 20;
```

**Gotcha:** `OFFSET` pagination gets progressively slower on large tables because the database must still scan/count through all skipped rows internally. For deep pagination on large datasets, "keyset pagination" (`WHERE id > :last_seen_id ORDER BY id LIMIT 10`) is far more efficient since it can use an index seek instead of scanning and discarding rows.

## FETCH FIRST

The ANSI SQL-standard way to limit rows, supported across PostgreSQL, Oracle, SQL Server (2012+), and DB2 — a portable alternative to the non-standard `LIMIT`.

```sql
SELECT * FROM products
ORDER BY price DESC
OFFSET 0 ROWS FETCH FIRST 10 ROWS ONLY;

-- With ties (includes additional rows tied with the last value)
SELECT * FROM products
ORDER BY price DESC
FETCH FIRST 10 ROWS WITH TIES;
```

`WITH TIES` is a particularly useful feature unavailable with plain `LIMIT` — it includes extra rows that tie with the last included row's sort value (e.g., "top 10 highest-paid employees," including all who tie for 10th place).

## Aliases

Aliases assign a temporary name to a column expression (`AS`) or a table (implicit or explicit `AS`), improving readability and enabling self-joins.

```sql
-- Column alias
SELECT first_name || ' ' || last_name AS full_name FROM employees;

-- Table alias (commonly required for joins, especially self-joins)
SELECT e.name AS employee_name, m.name AS manager_name
FROM employees e
JOIN employees m ON e.manager_id = m.id;
```

Table aliases are essential for self-joins (joining a table to itself) since you must disambiguate which "copy" of the table a column reference belongs to.

#### Interview Questions

1. **Why is `SELECT *` discouraged in production application code?**
   It fetches all columns even if only a few are needed, wasting bandwidth and I/O; it silently changes behavior if columns are added, removed, or reordered on the table; and it prevents the database from using certain optimizations (like index-only scans) that are possible when only specific columns are requested.
2. **What guarantee does SQL give about row order when no `ORDER BY` is specified?**
   None. The database is free to return rows in whatever order is most efficient for its execution plan, which can change between query runs, after adding an index, or after a version upgrade — code that depends on implicit ordering without `ORDER BY` is relying on undefined behavior.
3. **Why does deep `OFFSET`-based pagination become slow, and what's a better alternative?**
   `OFFSET` still requires the database to generate and then discard all skipped rows before returning the requested page, so performance degrades linearly (or worse) as the offset grows on large tables. Keyset/cursor-based pagination (filtering with `WHERE id > :last_id ORDER BY id LIMIT n`) uses an index seek directly to the starting point, giving consistent performance regardless of how deep the pagination goes.
4. **What does `FETCH FIRST ... WITH TIES` do, and why is it useful?**
   It extends a `FETCH FIRST n ROWS` limit to also include any additional rows that tie with the sort value of the last row in the limited set. This is useful for "top N" queries where ties should logically all be included (e.g., "top 3 highest scores" when multiple students share the 3rd-highest score).
5. **Is `DISTINCT` applied per-column or across the whole selected row?**
   Across the whole selected row — `SELECT DISTINCT col1, col2` deduplicates based on the combination of `col1` and `col2` together, not each column independently. If you need distinct values of just one column, select only that column.
6. **Why are table aliases required for self-joins?**
   A self-join references the same table twice in the `FROM`/`JOIN` clause, and without aliases, the database (and the reader) can't tell which occurrence a column reference belongs to. Aliases (e.g., `employees e JOIN employees m`) let you distinguish, for example, an employee row from its manager's row within the same query.
