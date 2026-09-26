# Filtering Data

## Comparison Operators

Comparison operators (`=`, `<>` / `!=`, `<`, `>`, `<=`, `>=`) test the relationship between two values and evaluate to `TRUE`, `FALSE`, or `UNKNOWN`. They are the building blocks of every `WHERE` and `HAVING` clause.

```sql
SELECT * FROM employees WHERE salary >= 50000;
SELECT * FROM orders WHERE status <> 'CANCELLED';
```

**Gotcha:** Any comparison involving `NULL` (e.g., `salary = NULL`) evaluates to `UNKNOWN`, not `TRUE` or `FALSE`, and the row is excluded from the result — you must use `IS NULL` / `IS NOT NULL` instead.

## Logical Operators

`AND`, `OR`, and `NOT` combine multiple boolean conditions. SQL follows three-valued logic (`TRUE`, `FALSE`, `UNKNOWN`), and operator precedence follows `NOT` > `AND` > `OR` — parentheses should be used liberally to avoid ambiguity.

```sql
SELECT * FROM employees
WHERE department = 'Engineering' AND (salary > 80000 OR years_experience > 5);
```

**Gotcha:** Mixing `AND`/`OR` without parentheses is a classic bug source — `WHERE dept = 'HR' OR dept = 'IT' AND salary > 60000` is parsed as `dept = 'HR' OR (dept = 'IT' AND salary > 60000)`, which usually surprises developers expecting left-to-right evaluation.

## BETWEEN

`BETWEEN` is syntactic sugar for an inclusive range check (`col >= low AND col <= high`).

```sql
SELECT * FROM orders WHERE order_date BETWEEN '2024-01-01' AND '2024-01-31';

-- Equivalent explicit form
SELECT * FROM orders WHERE order_date >= '2024-01-01' AND order_date <= '2024-01-31';
```

**Gotcha:** `BETWEEN` is inclusive on both ends. For date ranges spanning a full day, prefer `order_date >= '2024-01-01' AND order_date < '2024-02-01'` over `BETWEEN '2024-01-01' AND '2024-01-31 23:59:59'`, since the latter can silently miss timestamps with fractional seconds.

## IN

`IN` tests whether a value matches any value in an explicit list or a subquery result — shorthand for a chain of `OR`-ed equality checks.

```sql
SELECT * FROM employees WHERE department IN ('Engineering', 'Sales', 'Marketing');

-- Subquery form
SELECT * FROM employees
WHERE department_id IN (SELECT id FROM departments WHERE region = 'EMEA');
```

## NOT IN

`NOT IN` excludes rows matching any value in a list or subquery — but it has a well-known, dangerous pitfall with `NULL`.

```sql
SELECT * FROM employees WHERE department NOT IN ('Sales', 'Marketing');

-- DANGEROUS: if the subquery returns even one NULL, this returns ZERO rows
SELECT * FROM employees
WHERE department_id NOT IN (SELECT manager_id FROM employees); -- manager_id can be NULL
```

If the list/subquery for `NOT IN` contains a single `NULL`, the entire condition evaluates to `UNKNOWN` for every row (because `x <> NULL` is `UNKNOWN`, and `UNKNOWN AND ...` can never become `TRUE`), silently returning an empty result set. This is one of the most common real-world SQL bugs.

| Approach | NULL-safe? | Behavior when list contains NULL |
|---|---|---|
| `NOT IN (subquery)` | No | Returns zero rows (silently wrong) |
| `NOT EXISTS (correlated subquery)` | Yes | Works correctly regardless of NULLs |

**Best practice:** Prefer `NOT EXISTS` over `NOT IN` whenever the list/subquery could contain `NULL`s.

## LIKE

`LIKE` performs pattern matching using wildcards: `%` matches zero or more characters, `_` matches exactly one character.

```sql
SELECT * FROM customers WHERE last_name LIKE 'Sm_th%';   -- Smith, Smyth, Smithson...
SELECT * FROM products WHERE sku LIKE '10\%%' ESCAPE '\'; -- literal '%' via ESCAPE
```

**Gotcha:** A leading wildcard (`LIKE '%foo'`) cannot use a standard B-tree index efficiently since the engine can't seek — it typically falls back to a full scan (unless a trigram/full-text index is available).

## ILIKE (PostgreSQL)

`ILIKE` is PostgreSQL's case-insensitive variant of `LIKE`. It's not part of the ANSI standard; on other databases the equivalent is achieved with `LOWER(col) LIKE LOWER(pattern)` or a case-insensitive collation.

```sql
-- PostgreSQL only
SELECT * FROM users WHERE email ILIKE '%@GMAIL.com';

-- Portable equivalent
SELECT * FROM users WHERE LOWER(email) LIKE LOWER('%@gmail.com');
```

## IS NULL

## IS NOT NULL

Because `NULL` represents "unknown/absent" rather than a comparable value, standard comparison operators cannot detect it — `IS NULL` / `IS NOT NULL` are the only correct tools.

```sql
SELECT * FROM employees WHERE manager_id IS NULL;      -- top-level employees
SELECT * FROM employees WHERE termination_date IS NOT NULL; -- former employees
```

**Gotcha:** `WHERE column = NULL` never matches any row (it's always `UNKNOWN`), and most databases won't even raise a warning — this is a frequent source of "why is my query returning nothing?" bugs.

## EXISTS

## NOT EXISTS

`EXISTS` tests whether a (usually correlated) subquery returns *any* rows at all — it doesn't care about the actual row values, only their presence, and most engines short-circuit as soon as one matching row is found.

```sql
SELECT * FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.id AND o.total > 1000
);

SELECT * FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.id
); -- customers with no orders
```

Unlike `NOT IN`, `NOT EXISTS` handles `NULL`s correctly because it only checks for row existence under the correlation condition, never comparing values directly against `NULL`.

## ANY

## ALL

`ANY` (alias `SOME`) makes a comparison `TRUE` if it holds for *at least one* row returned by a subquery; `ALL` requires the comparison to hold for *every* row returned.

```sql
-- Employees earning more than at least one person in Sales (i.e., more than the minimum)
SELECT * FROM employees
WHERE salary > ANY (SELECT salary FROM employees WHERE department = 'Sales');

-- Employees earning more than everyone in Sales (i.e., more than the maximum)
SELECT * FROM employees
WHERE salary > ALL (SELECT salary FROM employees WHERE department = 'Sales');
```

| Construct | Equivalent to |
|---|---|
| `x = ANY (subquery)` | `x IN (subquery)` |
| `x <> ALL (subquery)` | `x NOT IN (subquery)` (same NULL pitfalls as `NOT IN`) |
| `x > ANY (subquery)` | `x > MIN(subquery)` |
| `x > ALL (subquery)` | `x > MAX(subquery)` |

#### Interview Questions

1. **Why does `WHERE department_id NOT IN (SELECT manager_id FROM employees)` sometimes return zero rows unexpectedly?**
   If the subquery returns even one `NULL` value (e.g., an employee with no manager), the entire `NOT IN` condition becomes `UNKNOWN` for every row, because comparing any value to `NULL` yields `UNKNOWN`, and `UNKNOWN` can never satisfy the `WHERE` clause. The safe fix is to use `NOT EXISTS` with a correlated subquery instead, or filter out NULLs explicitly (`WHERE manager_id IS NOT NULL`).
2. **Why does `WHERE salary = NULL` never return any rows?**
   SQL uses three-valued logic — comparing anything to `NULL` (including another `NULL`) produces `UNKNOWN`, never `TRUE`, so the row is excluded regardless of the actual value. You must use `IS NULL` (or `IS NOT NULL`) to test for null-ness explicitly.
3. **What's the difference between `EXISTS` and `IN`, and when would you prefer one over the other?**
   `EXISTS` only checks whether a correlated subquery returns any rows and typically short-circuits on the first match, making it NULL-safe and often efficient for large, non-indexed subquery sources. `IN` materializes/compares against a full list of values and can suffer from the `NOT IN`/NULL pitfall; for large subqueries, query optimizers often rewrite both into semi-joins, but `EXISTS` is generally the safer default, especially with `NOT`.
4. **Why can a leading wildcard `LIKE '%something'` hurt performance?**
   A B-tree index is sorted left-to-right, so the engine can only use it to seek when the pattern's prefix is fixed (e.g., `LIKE 'foo%'`). A leading `%` means there's no fixed prefix to seek on, forcing a full table/index scan unless a specialized index (trigram, full-text) is available.
5. **How would you write a case-insensitive search portably across databases that don't support `ILIKE`?**
   Wrap both sides in `LOWER()` (or `UPPER()`) consistently: `WHERE LOWER(email) LIKE LOWER('%@gmail.com')`. Alternatively, define the column with a case-insensitive collation so plain `=`/`LIKE` behave case-insensitively without extra function calls (which also preserves index usability if a matching function-based or collation-aware index exists).
6. **What does `salary > ANY (subquery)` mean compared to `salary > ALL (subquery)`?**
   `> ANY` is true if the salary exceeds at least one (i.e., the minimum) value returned by the subquery, while `> ALL` requires the salary to exceed every value (i.e., the maximum) returned. `> ANY (subquery)` is equivalent to `> (SELECT MIN(...) ...)` and `> ALL (subquery)` is equivalent to `> (SELECT MAX(...) ...)`.
