# SQL Functions

## String Functions

String functions manipulate text data — concatenation, substring extraction, case conversion, trimming, length, and search/replace.

```sql
SELECT CONCAT(first_name, ' ', last_name) AS full_name FROM employees;      -- ANSI
SELECT first_name || ' ' || last_name AS full_name FROM employees;          -- PostgreSQL/Oracle operator

SELECT UPPER(email), LOWER(email) FROM users;
SELECT TRIM('  padded  ');            -- 'padded'
SELECT LENGTH(description) FROM products;
SELECT SUBSTRING(sku FROM 1 FOR 3) AS category_code FROM products;
SELECT REPLACE(phone, '-', '') AS digits_only FROM contacts;
SELECT POSITION('@' IN email) AS at_index FROM users;
```

**Real-world use:** normalizing/cleaning data at the query level (e.g., stripping formatting from phone numbers) or building derived display columns (`full_name`) without denormalizing the schema.

## Numeric Functions

Numeric functions perform arithmetic and rounding/precision operations on numbers.

```sql
SELECT ROUND(price, 2) FROM products;      -- round to 2 decimal places
SELECT CEIL(4.1), FLOOR(4.9);              -- 5, 4
SELECT ABS(-15);                           -- 15
SELECT MOD(10, 3);                         -- 1 (equivalent to 10 % 3)
SELECT POWER(2, 10);                       -- 1024
SELECT SQRT(144);                          -- 12
```

**Gotcha:** integer division truncates in most databases — `SELECT 7 / 2` returns `3`, not `3.5`, unless one operand is cast to a decimal/float type (`SELECT 7 / 2.0`).

## Date Functions

Date functions extract, truncate, and perform arithmetic on date values.

```sql
SELECT CURRENT_DATE;
SELECT EXTRACT(YEAR FROM order_date) AS order_year FROM orders;
SELECT DATE_TRUNC('month', order_date) AS order_month FROM orders; -- PostgreSQL
SELECT order_date + INTERVAL '7 days' AS due_date FROM orders;      -- PostgreSQL
SELECT AGE(CURRENT_DATE, hire_date) FROM employees;                 -- PostgreSQL: interval difference
```

`DATE_TRUNC` is especially useful for reporting/grouping (e.g., grouping orders by month) without losing the ability to sort or index the result as a real date/timestamp.

## Time Functions

Time functions handle time-of-day and timestamp values, including timezone-aware variants.

```sql
SELECT CURRENT_TIME;
SELECT CURRENT_TIMESTAMP;                 -- date + time, session timezone
SELECT NOW();                             -- PostgreSQL alias for CURRENT_TIMESTAMP
SELECT CURRENT_TIMESTAMP AT TIME ZONE 'UTC'; -- convert to a specific timezone
```

**Best practice:** store timestamps as `TIMESTAMPTZ` (timestamp with time zone) in PostgreSQL and always reason in UTC internally, converting to local time only at the presentation layer — mixing naive and timezone-aware timestamps is a common source of off-by-hours bugs.

## Conversion Functions

Conversion functions explicitly change a value's data type, avoiding reliance on implicit (and sometimes surprising) type coercion.

```sql
SELECT CAST(price AS INTEGER) FROM products;   -- ANSI standard
SELECT price::INTEGER FROM products;           -- PostgreSQL shorthand
SELECT TO_CHAR(order_date, 'YYYY-MM-DD') FROM orders;  -- PostgreSQL/Oracle
SELECT TO_NUMBER('1234.56', '9999.99');                -- PostgreSQL/Oracle
SELECT TO_DATE('2024-01-15', 'YYYY-MM-DD');
```

**Gotcha:** implicit conversions (e.g., comparing a `VARCHAR` column to a numeric literal) can silently prevent index usage or throw runtime errors on invalid data — explicit `CAST`/`::` makes intent clear and is easier to reason about.

## NULL Handling Functions

`COALESCE` and `NULLIF` provide portable, standard ways to handle `NULL` values without vendor-specific functions.

```sql
SELECT COALESCE(nickname, first_name, 'Unknown') AS display_name FROM users;

-- Avoid divide-by-zero: NULLIF returns NULL when the two arguments are equal
SELECT total_revenue / NULLIF(total_orders, 0) AS avg_order_value FROM sales_summary;
```

`COALESCE(a, b, c, ...)` returns the first non-`NULL` argument; it's the ANSI-standard, portable replacement for vendor-specific functions like `ISNULL` (SQL Server) or `IFNULL` (MySQL).

## Conditional Functions

`CASE` expressions provide if/else-style branching logic directly inside a query, usable in `SELECT`, `WHERE`, `ORDER BY`, and `GROUP BY`.

```sql
-- Simple CASE (single expression compared against values)
SELECT name,
    CASE department
        WHEN 'ENG' THEN 'Engineering'
        WHEN 'SLS' THEN 'Sales'
        ELSE 'Other'
    END AS department_name
FROM employees;

-- Searched CASE (arbitrary boolean conditions per branch)
SELECT name,
    CASE
        WHEN salary >= 100000 THEN 'Senior'
        WHEN salary >= 60000  THEN 'Mid'
        ELSE 'Junior'
    END AS band
FROM employees;
```

`CASE` is standard ANSI SQL and portable everywhere; Oracle's `DECODE` predates `CASE` and only supports simple equality branching, so `CASE` is generally preferred for new code.

#### Interview Questions

1. **Why does `SELECT 7 / 2` return `3` instead of `3.5` in most databases?**
   When both operands are integers, most SQL engines perform integer division and truncate the result, following the type of the operands. To get a fractional result, cast at least one operand to a decimal/float type, e.g., `7 / 2.0` or `CAST(7 AS DECIMAL) / 2`.
2. **What's the ANSI-standard, portable way to handle `NULL` fallback values, and how does it differ from vendor functions like `ISNULL`/`IFNULL`?**
   `COALESCE(a, b, c, ...)` returns the first non-`NULL` value among any number of arguments and is part of the SQL standard, making it portable across PostgreSQL, MySQL, SQL Server, and Oracle. `ISNULL` (SQL Server) and `IFNULL` (MySQL) are vendor-specific, typically accept only two arguments, and sometimes have subtly different type-coercion rules.
3. **How would you safely avoid a divide-by-zero error when computing an average in SQL?**
   Use `NULLIF(divisor, 0)` so the divisor becomes `NULL` when it's zero, which makes the whole division return `NULL` instead of raising an error: `total / NULLIF(count, 0)`.
4. **What's the difference between a "simple" `CASE` and a "searched" `CASE` expression?**
   A simple `CASE` compares one expression against a list of values (`CASE dept WHEN 'ENG' THEN ...`), similar to a switch statement. A searched `CASE` evaluates independent boolean conditions per branch (`CASE WHEN salary > 100000 THEN ...`), which is more flexible since each branch can reference different columns/conditions.
5. **Why should you prefer explicit `CAST`/`::` over relying on implicit type conversion?**
   Implicit conversions can silently prevent the optimizer from using an index (e.g., comparing an indexed `VARCHAR` column against a numeric literal may force a full scan), can throw unexpected runtime errors on malformed data, and make the intended type of an expression less obvious to future readers. Explicit casting documents intent and behaves predictably across database versions.
6. **Why is storing timestamps as timezone-aware (e.g., PostgreSQL `TIMESTAMPTZ`) generally recommended over naive timestamps?**
   Timezone-aware columns are always normalized to UTC internally, so comparisons, sorting, and arithmetic are unambiguous regardless of the server's or client's local timezone. Naive timestamps require the application to track and convert timezones manually, which is a frequent source of off-by-hours bugs, especially around daylight saving time transitions.

## Aggregate Functions

## COUNT

`COUNT` returns the number of rows. `COUNT(*)` counts all rows regardless of `NULL`s; `COUNT(column)` counts only rows where that column is non-`NULL`.

```sql
SELECT COUNT(*) FROM employees;                       -- total row count
SELECT COUNT(commission) FROM employees;              -- rows where commission IS NOT NULL
SELECT COUNT(DISTINCT department) FROM employees;     -- number of unique departments
```

**Gotcha:** `COUNT(column)` and `COUNT(*)` can return different numbers on the same table if `column` contains `NULL`s — this trips up many developers who assume they're interchangeable.

## SUM

`SUM` totals a numeric column, ignoring `NULL` values (treating them as if absent, not zero).

```sql
SELECT SUM(total) AS revenue FROM orders WHERE status = 'COMPLETED';
```

**Gotcha:** `SUM` over an empty set (zero matching rows) returns `NULL`, not `0` — wrap with `COALESCE(SUM(total), 0)` if a zero default is required downstream.

## AVG

`AVG` computes the arithmetic mean of a numeric column, also ignoring `NULL`s (they aren't counted as zero and don't affect the denominator).

```sql
SELECT AVG(salary) FROM employees WHERE department = 'Engineering';
```

**Gotcha:** if the column is an integer type, some databases perform integer division internally for intermediate steps — verify actual behavior, or cast explicitly (`AVG(salary::NUMERIC)`) to guarantee a fractional result.

## MIN

## MAX

`MIN`/`MAX` return the smallest/largest value in a column — they work on numeric, string (lexicographic), and date/time types alike.

```sql
SELECT MIN(hire_date), MAX(hire_date) FROM employees;
SELECT MIN(last_name) FROM employees; -- alphabetically first
```

## DISTINCT Aggregates

Combining `DISTINCT` with an aggregate function deduplicates values *before* aggregating, useful for counting/summing unique values rather than all occurrences.

```sql
SELECT COUNT(DISTINCT customer_id) AS unique_customers FROM orders;
SELECT SUM(DISTINCT price) FROM products; -- sums each distinct price once (rarely what you want for totals)
```

**Real-world use:** `COUNT(DISTINCT customer_id)` is the standard way to compute "unique customers" from an orders table where each customer may have placed multiple orders — a very common reporting/analytics query.

#### Interview Questions

1. **What's the difference between `COUNT(*)` and `COUNT(column_name)`?**
   `COUNT(*)` counts all rows in the group regardless of `NULL` values, while `COUNT(column_name)` counts only rows where that specific column is non-`NULL`. If the column has nulls, the two will return different numbers.
2. **Why does `SUM(total)` return `NULL` instead of `0` when no rows match the `WHERE` clause?**
   Aggregate functions (except `COUNT`) return `NULL` when applied to an empty set because there's no data to aggregate — SQL treats "no rows" differently from "a sum of zero." Use `COALESCE(SUM(total), 0)` if you need a guaranteed numeric default.
3. **Do aggregate functions like `SUM`, `AVG`, `MIN`, and `MAX` include `NULL` values in their calculation?**
   No — all standard aggregate functions ignore `NULL` values entirely (they're excluded from both the calculation and, for `AVG`, the denominator count). Only `COUNT(*)` counts rows without regard to `NULL`s.
4. **How do you count the number of distinct customers who placed at least one order?**
   `SELECT COUNT(DISTINCT customer_id) FROM orders;` — this deduplicates customer IDs before counting, so a customer with multiple orders is only counted once.
5. **Can you use an aggregate function without a `GROUP BY` clause? What happens?**
   Yes — without `GROUP BY`, the entire result set is treated as a single implicit group, and the aggregate function returns one row summarizing all matching rows (e.g., `SELECT COUNT(*) FROM employees` returns a single total).
6. **Why might `AVG` behave unexpectedly on an integer column, and how do you fix it?**
   Depending on the database, intermediate computation for `AVG` on integer types can involve integer division/truncation issues in edge cases, and the returned type may itself be an integer, silently truncating a fractional result. Casting explicitly (e.g., `AVG(salary::NUMERIC)` or `AVG(CAST(salary AS DECIMAL))`) guarantees a precise fractional average.
