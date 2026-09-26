# SQL and Query Languages

## Theory

### Query Languages Overview (DDL, DML, DCL, TCL)

SQL commands are grouped into four sublanguages based on their purpose:

| Category | Full Name | Purpose | Example Commands |
|---|---|---|---|
| DDL | Data Definition Language | Defines/alters schema structure | `CREATE`, `ALTER`, `DROP`, `TRUNCATE` |
| DML | Data Manipulation Language | Manipulates data within tables | `SELECT`, `INSERT`, `UPDATE`, `DELETE` |
| DCL | Data Control Language | Manages access/permissions | `GRANT`, `REVOKE` |
| TCL | Transaction Control Language | Manages transaction boundaries | `COMMIT`, `ROLLBACK`, `SAVEPOINT` |

```sql
-- DDL
CREATE TABLE products (id INT PRIMARY KEY, name VARCHAR(100));

-- DML
INSERT INTO products (id, name) VALUES (1, 'Widget');

-- DCL
GRANT SELECT ON products TO reporting_user;

-- TCL
BEGIN;
UPDATE products SET name = 'Gadget' WHERE id = 1;
COMMIT;
```

### Joins Overview (Inner, Outer, Cross, Self)

A join combines rows from two or more tables based on a related column. **Inner join** returns only rows with matches in both tables. **Outer joins** (`LEFT`, `RIGHT`, `FULL`) return matched rows plus unmatched rows from one or both sides, filling in `NULL` for missing columns. **Cross join** returns the Cartesian product of both tables (every row paired with every row). **Self join** joins a table to itself, typically to compare rows within the same table (e.g., an employee-to-manager relationship).

```sql
-- INNER JOIN: only customers who have orders
SELECT c.name, o.order_id
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;

-- LEFT OUTER JOIN: all customers, with NULLs for those without orders
SELECT c.name, o.order_id
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id;

-- SELF JOIN: employees and their managers
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;
```

**Differences: Inner vs Outer vs Cross vs Self Join**

| Join Type | Returns | Unmatched Rows |
|---|---|---|
| Inner | Only matching rows from both tables | Excluded |
| Left Outer | All rows from left table + matches from right | Right side `NULL`-filled |
| Right Outer | All rows from right table + matches from left | Left side `NULL`-filled |
| Full Outer | All rows from both tables | Both sides `NULL`-filled where unmatched |
| Cross | Cartesian product (every row × every row) | N/A (no join condition) |
| Self | Table joined with itself via an alias | Depends on join type used |

### Set Operations (Union, Intersect, Except)

Set operations combine the results of two or more `SELECT` queries that must have the same number of columns with compatible types. `UNION` returns all distinct rows from either query (`UNION ALL` keeps duplicates). `INTERSECT` returns only rows present in both result sets. `EXCEPT` (or `MINUS` in some databases) returns rows in the first query that are not in the second.

```sql
SELECT city FROM customers
UNION
SELECT city FROM suppliers;

SELECT customer_id FROM orders_2025
INTERSECT
SELECT customer_id FROM orders_2026;

SELECT customer_id FROM all_customers
EXCEPT
SELECT customer_id FROM churned_customers;
```

### Subqueries

A subquery is a query nested inside another query, used in the `SELECT`, `FROM`, or `WHERE` clause. Subqueries can be **scalar** (return one value), **row/column** (return a list), or **correlated** (reference a column from the outer query, re-evaluated per outer row).

```sql
-- Subquery in WHERE clause
SELECT name FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees);

-- Correlated subquery
SELECT e.name FROM employees e
WHERE EXISTS (
    SELECT 1 FROM orders o WHERE o.employee_id = e.id
);
```

### Views

A view is a virtual table defined by a stored `SELECT` query — it does not store data itself (unless it's a materialized view) but presents data dynamically from the underlying tables each time it's queried. Views are useful for simplifying complex queries, enforcing security by restricting visible columns/rows, and providing a stable interface even if underlying tables change.

```sql
CREATE VIEW active_customers AS
SELECT id, name, email
FROM customers
WHERE status = 'ACTIVE';

SELECT * FROM active_customers;
```

- **Advantages**
  - Simplifies repeated complex queries and hides join/filter logic.
  - Can restrict access to sensitive columns/rows for security.
- **Disadvantages**
  - Regular views add query overhead (re-executed each time, no stored data).
  - Can be harder to debug/optimize when nested many layers deep.

### Stored Procedures

A stored procedure is a precompiled, named block of SQL (and often procedural logic like loops and conditionals) stored in the database and invoked by name. Stored procedures reduce network round-trips, allow reuse of business logic across applications, and can improve performance since the execution plan may be cached.

```sql
CREATE PROCEDURE GetOrdersByCustomer (IN cust_id INT)
BEGIN
    SELECT * FROM orders WHERE customer_id = cust_id;
END;

CALL GetOrdersByCustomer(42);
```

### Triggers

A trigger is a piece of procedural code that automatically executes in response to a specific event (`INSERT`, `UPDATE`, `DELETE`) on a table, either `BEFORE` or `AFTER` the event. Triggers are commonly used for auditing, enforcing complex business rules, and maintaining derived/denormalized data automatically.

```sql
CREATE TRIGGER trg_audit_salary_update
AFTER UPDATE ON employees
FOR EACH ROW
BEGIN
    INSERT INTO salary_audit (employee_id, old_salary, new_salary, changed_at)
    VALUES (OLD.id, OLD.salary, NEW.salary, NOW());
END;
```

### Cursors

A cursor is a database object that allows row-by-row, sequential processing of a result set — useful when logic must operate on one row at a time (e.g., complex procedural transformations) rather than as a set. Cursors are generally discouraged for routine data processing because set-based SQL operations are far more efficient.

```sql
DECLARE cur CURSOR FOR SELECT id, salary FROM employees;
OPEN cur;
FETCH NEXT FROM cur INTO @id, @salary;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- process one row at a time
    FETCH NEXT FROM cur INTO @id, @salary;
END;
CLOSE cur;
DEALLOCATE cur;
```

- **Advantages**
  - Enables row-by-row procedural logic when set-based SQL can't easily express it.
- **Disadvantages**
  - Much slower than set-based operations due to per-row overhead.
  - Holds locks/resources longer, potentially reducing concurrency.

**Differences: Stored Procedure vs Trigger vs View**

| Aspect | Stored Procedure | Trigger | View |
|---|---|---|---|
| Invocation | Explicitly called (`CALL`/`EXEC`) | Automatically fired by an event | Queried like a table (`SELECT`) |
| Purpose | Encapsulate reusable logic/operations | React to data changes automatically | Present a simplified/virtual dataset |
| Can modify data | Yes | Yes | Generally no (unless updatable view) |
| Returns a result set | Optional | No | Yes (always) |

### Interview Questions

- **Q: Write a query using an INNER JOIN and explain when a covering index would help.**
  A: `SELECT c.name, o.order_id FROM customers c INNER JOIN orders o ON c.id = o.customer_id;` — a covering index on `orders(customer_id, order_id)` would let the engine satisfy the join's needs directly from the index without touching the `orders` table data, speeding up the join significantly.
- **Q: What is the difference between `UNION` and `UNION ALL`?**
  A: `UNION` removes duplicate rows from the combined result (requiring a sort/dedup step), while `UNION ALL` keeps all rows including duplicates and is faster since no deduplication occurs.
- **Q: What is a correlated subquery, and why can it be slow?**
  A: A subquery that references a column from the outer query, causing it to be logically re-evaluated for every row of the outer query, which can be expensive without proper indexing.
- **Q: When would you use a LEFT JOIN instead of an INNER JOIN?**
  A: When you need all rows from the left table regardless of whether a match exists in the right table, e.g., listing all customers including those with zero orders.
- **Q: What's the difference between a view and a materialized view?**
  A: A regular view stores only the query definition and is re-executed on each access, while a materialized view stores the actual computed result physically and must be refreshed periodically.
- **Q: Why are cursors generally discouraged in SQL?**
  A: They process rows one at a time, losing the performance benefits of set-based operations and often holding locks longer, hurting throughput and concurrency compared to equivalent set-based queries.
- **Q: What is the difference between DDL and DML commands?**
  A: DDL commands (`CREATE`, `ALTER`, `DROP`) define or modify the schema structure, while DML commands (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) manipulate the actual data within that structure.
- **Q: When would a trigger be a better choice than adding logic in application code?**
  A: When the rule must be enforced consistently regardless of which application or client modifies the data (e.g., auditing every change to a table), since the trigger runs at the database level.
- **Q: How does a self join work, and give an example use case.**
  A: It joins a table to itself using aliases to treat it as two logical tables, commonly used for hierarchical data such as matching employees to their managers within the same `employees` table.
- **Q: What does `EXCEPT` (or `MINUS`) return?**
  A: All rows returned by the first query that do not appear in the second query's result set.

