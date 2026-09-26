# Indexes

An index is an auxiliary data structure (typically a B-tree) that lets the database locate rows matching a condition without scanning the entire table, at the cost of extra storage and slower writes (since the index must also be maintained).

## CREATE INDEX

The basic form creates a B-tree index (the default in most relational databases) on one or more columns.

```sql
CREATE INDEX idx_employees_department ON employees (department);
```

- Speeds up `WHERE department = 'Engineering'`, `ORDER BY department`, and equality/range joins on that column.
- B-tree is the default and general-purpose choice because it efficiently supports equality, range (`<`, `>`, `BETWEEN`), and sorting operations — most other index types (hash, GiST, GIN, BRIN in PostgreSQL) are specialized for particular data types or query patterns.

## DROP INDEX

Removing an index is straightforward but should be done deliberately, since it immediately affects the query plans of anything relying on it.

```sql
DROP INDEX idx_employees_department;
```

Indexes are usually dropped when they're no longer used (verify via the database's usage statistics, e.g., PostgreSQL's `pg_stat_user_indexes`), when they duplicate another index's leading columns, or when their write-maintenance cost outweighs their read benefit.

## Composite Index

A composite (multi-column) index covers more than one column, and the **column order matters enormously** — it follows the "leftmost prefix" rule.

```sql
CREATE INDEX idx_employees_dept_salary ON employees (department, salary);

-- Uses the index efficiently (leftmost column present):
SELECT * FROM employees WHERE department = 'Engineering';
SELECT * FROM employees WHERE department = 'Engineering' AND salary > 80000;

-- Cannot use this index efficiently (leftmost column missing):
SELECT * FROM employees WHERE salary > 80000;
```

The index is physically sorted first by `department`, then by `salary` within each department — so it's usable for queries filtering by `department` alone, or by `department` + `salary` together, but not for filtering by `salary` alone, since matching salary values are scattered across many different department groupings in the index structure.

## Unique Index

A unique index enforces that no two rows share the same value (or combination of values) in the indexed column(s), while also providing the same lookup speedup as a regular index.

```sql
CREATE UNIQUE INDEX idx_employees_email ON employees (email);
```

Declaring a column `UNIQUE` in a table constraint typically creates an underlying unique index automatically (implementation detail of the database) — so a unique constraint and a manually created unique index usually end up being functionally equivalent, differing mainly in how they're declared and documented.

## Partial Index (Overview)

A partial index (PostgreSQL feature) only indexes rows matching a `WHERE` condition, making it smaller and faster to maintain than a full-table index when only a subset of rows is commonly queried.

```sql
CREATE INDEX idx_active_employees_email ON employees (email) WHERE status = 'ACTIVE';

-- Uses the partial index efficiently:
SELECT * FROM employees WHERE status = 'ACTIVE' AND email = 'jane@example.com';
```

Ideal when queries almost always filter on a specific, stable condition (e.g., only "active" or "unprocessed" rows), since it avoids indexing the majority of rows that are rarely queried.

## Functional Index (Overview)

A functional (expression) index indexes the *result of an expression* applied to a column, rather than the raw column value — useful when queries filter on a transformed/derived form of the data.

```sql
CREATE INDEX idx_employees_email_lower ON employees (LOWER(email));

-- Uses the functional index efficiently:
SELECT * FROM employees WHERE LOWER(email) = 'jane@example.com';
```

Without the functional index, applying `LOWER()` to the column in a `WHERE` clause would prevent the optimizer from using a plain index on `email` directly, since the indexed values (raw case) don't match the transformed search value.

## Index Usage

The query optimizer decides whether to use an available index based on cost estimates derived from table/column statistics — it doesn't use an index just because one exists.

- **Selectivity**: how many rows match a condition relative to the table's total size. Highly selective conditions (few matching rows, e.g., a unique email) benefit greatly from an index; low-selectivity conditions (e.g., a boolean column with a 50/50 split) often don't, because scanning the whole table sequentially can be cheaper than jumping around via an index.
- **Statistics**: the planner relies on up-to-date statistics (row counts, value distribution/histograms) — run `ANALYZE` (PostgreSQL) after major data changes so the planner's cost estimates stay accurate.
- **Data type/operator compatibility**: an index only helps if the query's `WHERE`/`JOIN`/`ORDER BY` uses operators the index supports (e.g., a B-tree index doesn't help with `LIKE '%text%'` pattern matches without a specialized index type like GIN with `pg_trgm`).

## When Not to Use Indexes

Indexes aren't free — every index adds overhead to `INSERT`/`UPDATE`/`DELETE` (the index must be kept in sync) and consumes additional storage, so blindly indexing every column is counterproductive.

- **Small tables**: a sequential scan of a small table is often faster than the overhead of an index lookup (traversing a B-tree, then fetching rows) — the optimizer usually detects this and ignores the index anyway.
- **Low-selectivity columns**: indexing a column with very few distinct values (e.g., a boolean `is_deleted` flag) rarely helps, since a large fraction of rows would match any given value.
- **Write-heavy tables**: tables with frequent `INSERT`/`UPDATE`/`DELETE` pay a real cost for every index — each write must also update every index on the table, so excess indexes slow down writes disproportionately to their read benefit.
- **Columns rarely used in filters/joins/sorts**: an index that's never chosen by the optimizer is pure overhead — periodically audit and drop unused indexes.
- **Very wide or frequently updated columns**: indexing large text columns (unless a specialized index type is used) or columns updated on nearly every write increases index bloat and maintenance cost significantly.

| Index Type | Best For | Notes |
|---|---|---|
| B-tree (default) | Equality, range, sorting | General-purpose, most common |
| Hash | Pure equality lookups | Rarely needed over B-tree in modern PostgreSQL |
| GIN | Full-text search, array/JSONB containment | Larger, slower to update, fast for "contains" queries |
| GiST | Geometric data, range types, nearest-neighbor | Used for specialized data types |
| BRIN | Very large, naturally ordered tables (e.g., time-series) | Tiny index size, coarse-grained |
| Partial | Queries that always filter on a known subset | Smaller than a full index |

#### Interview Questions

1. **Why doesn't adding an index always speed up a query?**
   The optimizer only uses an index if its cost model estimates it's cheaper than a sequential scan — for low-selectivity columns, small tables, or queries returning a large fraction of rows, scanning sequentially can be faster than the random I/O of index lookups plus row fetches. Outdated table statistics can also cause the optimizer to make a suboptimal choice.
2. **What is the "leftmost prefix" rule for composite indexes, and why does it matter?**
   A composite index on `(a, b)` is physically sorted first by `a`, then by `b` within each `a` value. It can efficiently serve queries filtering on `a` alone, or on `a` and `b` together, but not on `b` alone, because matching `b` values are scattered non-contiguously across the index. Column order should match the most common query patterns, typically putting the most selective or most-frequently-filtered column first (though exact ordering depends on query patterns).
3. **When would you avoid adding an index, even though it would technically speed up some query?**
   On tables with heavy write throughput, where the write-side cost of maintaining an extra index (updating it on every `INSERT`/`UPDATE`/`DELETE`) outweighs the read-side benefit for a rarely-run query; on very small tables where a sequential scan is already fast; or on low-selectivity columns where the index provides little to no pruning benefit.
4. **What's the difference between a unique constraint and a unique index?**
   Functionally they usually achieve the same outcome — most databases implement a unique constraint using an underlying unique index automatically. The main difference is intent/documentation: a `UNIQUE` constraint declares a business rule as part of the table definition, while creating a unique index directly is a more implementation-focused way to get the same enforcement plus the lookup speed benefit.
5. **What is a partial index and when would you use one?**
   A partial index only indexes rows matching a specified `WHERE` condition (e.g., `WHERE status = 'ACTIVE'`), making it smaller and cheaper to maintain than indexing the whole table. It's ideal when queries consistently filter on a known subset of rows (like only active or unprocessed records) and the excluded rows are rarely or never queried by that predicate.
6. **Why would `WHERE LOWER(email) = 'x'` not use a plain index on `email`, and how do you fix it?**
   A standard index stores the column's raw values, sorted as-is; applying a function like `LOWER()` in the query transforms the search value before comparison, so it no longer matches the index's stored (untransformed) values directly, forcing a sequential scan. The fix is a functional (expression) index built on `LOWER(email)` itself, so the index stores the already-transformed values and can be matched directly.
