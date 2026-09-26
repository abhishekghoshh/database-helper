# GROUP BY

## GROUP BY

`GROUP BY` collapses rows sharing the same value(s) in specified column(s) into a single summary row per group, typically used alongside aggregate functions.

```sql
SELECT department, COUNT(*) AS headcount, AVG(salary) AS avg_salary
FROM employees
GROUP BY department;
```

Understanding SQL's **logical query processing order** is essential for reasoning about `GROUP BY`/`HAVING`/`WHERE` interactions — clauses are conceptually evaluated in this order, not the order they're written:

```mermaid
flowchart LR
    A[FROM / JOIN] --> B[WHERE]
    B --> C[GROUP BY]
    C --> D[HAVING]
    D --> E[SELECT]
    E --> F[ORDER BY]
    F --> G[LIMIT / OFFSET]
```

This is why `WHERE` cannot reference column aliases defined in `SELECT`, and why aggregate functions cannot be used in `WHERE` (the rows aren't grouped yet at that stage).

## HAVING

`HAVING` filters *groups* after aggregation, whereas `WHERE` filters individual *rows* before grouping. `HAVING` is the only clause that can reference aggregate function results.

```sql
SELECT department, COUNT(*) AS headcount
FROM employees
GROUP BY department
HAVING COUNT(*) > 10;

-- WHERE and HAVING can be combined: filter rows first, then filter resulting groups
SELECT department, AVG(salary) AS avg_salary
FROM employees
WHERE hire_date >= '2020-01-01'
GROUP BY department
HAVING AVG(salary) > 70000;
```

| Clause | Filters | Can reference aggregates? | Evaluated |
|---|---|---|---|
| `WHERE` | Individual rows | No | Before `GROUP BY` |
| `HAVING` | Groups (post-aggregation) | Yes | After `GROUP BY` |

**Gotcha:** Putting a row-level filter in `HAVING` instead of `WHERE` (e.g., `HAVING department = 'Sales'`) works but is wasteful — it forces the database to group all rows first, then discard whole groups, instead of filtering rows before the (potentially expensive) grouping step.

## Multiple Grouping Columns

Grouping by more than one column creates a group for every unique *combination* of those columns' values, effectively grouping hierarchically.

```sql
SELECT department, job_title, COUNT(*) AS headcount
FROM employees
GROUP BY department, job_title
ORDER BY department, job_title;
```

**Advanced note:** `GROUP BY ROLLUP(department, job_title)` and `GROUP BY CUBE(department, job_title)` (PostgreSQL, Oracle, SQL Server) extend this to also produce subtotal and grand-total rows automatically, useful for reporting dashboards without manual `UNION ALL` of multiple aggregation levels.

## GROUP BY with Aggregate Functions

Every column in the `SELECT` list that is *not* wrapped in an aggregate function must appear in the `GROUP BY` clause — otherwise the database cannot determine a single value to display for that column per group.

```sql
-- Valid: job_title is grouped, headcount/avg_salary are aggregated
SELECT department, job_title, COUNT(*) AS headcount, AVG(salary) AS avg_salary
FROM employees
GROUP BY department, job_title;

-- INVALID in standard SQL / PostgreSQL: job_title is neither grouped nor aggregated
SELECT department, job_title, COUNT(*)
FROM employees
GROUP BY department; -- ERROR: column "employees.job_title" must appear in GROUP BY or be used in an aggregate function
```

**Gotcha:** MySQL historically allowed this "invalid" form (returning an arbitrary value per group) unless `ONLY_FULL_GROUP_BY` SQL mode is enabled — relying on this non-standard leniency produces non-deterministic, hard-to-debug results and should be avoided even where permitted.

#### Interview Questions

1. **What is the key difference between `WHERE` and `HAVING`?**
   `WHERE` filters individual rows *before* grouping/aggregation occurs and cannot reference aggregate function results, while `HAVING` filters entire groups *after* aggregation and can reference aggregates like `COUNT(*)` or `AVG(col)`. As a performance rule of thumb, push any filter that doesn't depend on an aggregate into `WHERE` so fewer rows need to be grouped.
2. **What is SQL's logical query processing order, and why does it matter?**
   Conceptually: `FROM`/`JOIN` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `ORDER BY` → `LIMIT`/`OFFSET`. It matters because it explains why you can't filter on a `SELECT`-list alias in `WHERE` (aliases don't exist yet at that stage) and why aggregate functions are only usable starting at the `GROUP BY`/`HAVING` stage.
3. **Why must every non-aggregated column in the `SELECT` list also appear in `GROUP BY`?**
   Because `GROUP BY` collapses multiple rows into one output row per group, the database needs a deterministic single value for every selected column. Aggregate functions (`COUNT`, `SUM`, etc.) provide that by design, but a plain column not in `GROUP BY` could have many different values within a group, so standard SQL requires it to be either grouped or aggregated.
4. **What do `ROLLUP` and `CUBE` add on top of a plain `GROUP BY`?**
   Both generate additional subtotal/grand-total rows automatically: `ROLLUP` produces subtotals along a hierarchical rollup of the grouping columns (e.g., per-department, then a grand total), while `CUBE` produces subtotals for every possible combination of the grouping columns. They're commonly used to power reporting dashboards without stitching together multiple `UNION ALL` queries.
5. **If you need to filter on an aggregate value but also want to minimize the rows processed by grouping, what should you do?**
   Filter as much as possible in `WHERE` first (row-level, pre-aggregation conditions), and reserve `HAVING` strictly for conditions that depend on the aggregate result itself (e.g., `HAVING COUNT(*) > 10`). Putting row-level conditions in `HAVING` forces the database to group unnecessary rows before discarding them.
6. **Why does MySQL sometimes allow non-aggregated, non-grouped columns in `SELECT`, and why is this risky?**
   Unless `ONLY_FULL_GROUP_BY` SQL mode is enabled, MySQL permits this by picking an arbitrary (often the first-encountered) value for the ungrouped column within each group. This produces results that are non-deterministic and can change between query runs or server versions, so it should be avoided even when the database allows it.
