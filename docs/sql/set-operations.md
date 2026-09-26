# Set Operations

Set operations combine the results of two or more `SELECT` queries. All queries involved must return the **same number of columns**, with **compatible data types** in corresponding positions — column names are taken from the first query.

## UNION

`UNION` combines the result sets of two queries and removes duplicate rows across the combined set (like `DISTINCT` applied to the union).

```sql
SELECT name, email FROM customers
UNION
SELECT name, email FROM newsletter_subscribers;
```

## UNION ALL

`UNION ALL` combines result sets *without* removing duplicates — it's simpler and faster since it skips the deduplication step entirely.

```sql
SELECT name, email FROM customers
UNION ALL
SELECT name, email FROM newsletter_subscribers;
```

| Operation | Removes duplicates? | Relative performance |
|---|---|---|
| `UNION` | Yes | Slower (requires sort/hash to dedupe) |
| `UNION ALL` | No | Faster |

**Best practice:** default to `UNION ALL` unless duplicate removal is actually required — deduplication forces the database to sort or hash the entire combined result set, which is wasted work if the source queries are already known to be disjoint or duplicates are acceptable.

## INTERSECT

`INTERSECT` returns only the rows that appear in *both* result sets (set intersection), removing duplicates.

```sql
-- Customers who are also newsletter subscribers
SELECT email FROM customers
INTERSECT
SELECT email FROM newsletter_subscribers;
```

`INTERSECT` is often more readable than the equivalent `INNER JOIN` or `WHERE ... IN (subquery)` formulation when the intent is genuinely "rows common to both sets."

## EXCEPT / MINUS

`EXCEPT` (PostgreSQL, SQL Server) — called `MINUS` in Oracle — returns rows from the first query that do **not** appear in the second query's results (set difference).

```sql
-- Customers who have never subscribed to the newsletter
SELECT email FROM customers
EXCEPT
SELECT email FROM newsletter_subscribers;

-- Oracle equivalent
-- SELECT email FROM customers MINUS SELECT email FROM newsletter_subscribers;
```

| Set Operation | Meaning | SQL Keyword(s) |
|---|---|---|
| Union | All rows from either set (deduped) | `UNION` |
| Union (with duplicates) | All rows from either set (kept) | `UNION ALL` |
| Intersection | Rows in both sets | `INTERSECT` |
| Difference | Rows in first set only | `EXCEPT` (Oracle: `MINUS`) |

#### Interview Questions

1. **What's the difference between `UNION` and `UNION ALL`, and which should you default to?**
   `UNION` removes duplicate rows from the combined result (requiring an internal sort/hash pass), while `UNION ALL` keeps all rows including duplicates and is therefore faster. Default to `UNION ALL` unless you specifically need deduplication, since the dedup step in plain `UNION` adds real overhead on large result sets.
2. **What requirement must the participating queries in a `UNION`/`INTERSECT`/`EXCEPT` satisfy?**
   Each query must return the same number of columns, with data types that are compatible (implicitly convertible) in each corresponding column position; column names in the final result come from the first query in the set operation.
3. **How would you find rows that exist in table A but not in table B using a set operation, and what's the Oracle-specific keyword?**
   `SELECT cols FROM A EXCEPT SELECT cols FROM B;` — in Oracle, the equivalent keyword is `MINUS` instead of `EXCEPT`, but the semantics are identical.
4. **Could you rewrite `INTERSECT` using a `JOIN` or `IN`/`EXISTS`? Why might you still prefer `INTERSECT`?**
   Yes — `INTERSECT` can be rewritten as an `INNER JOIN` on all matching columns or a correlated `WHERE ... IN (subquery)`. `INTERSECT` is often preferred purely for readability when the intent is "rows common to two full result sets," rather than a join on a specific key relationship.
5. **If you combine `UNION` with `ORDER BY`, where does the `ORDER BY` clause go?**
   Only one `ORDER BY` is allowed, placed at the very end after the last `SELECT` in the set operation chain — it applies to the entire combined result set, not to an individual `SELECT`, and can only reference output column names/positions (not table-qualified names from a specific branch).
