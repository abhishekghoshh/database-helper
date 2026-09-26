# Database Constraints

## Theory

### Entity Integrity

Entity integrity ensures that every row in a table can be uniquely identified — enforced by requiring a primary key to be both unique and non-null. Without entity integrity, there would be no reliable way to distinguish one record from another or reference it from other tables.

```sql
CREATE TABLE employee (
    employee_id INT PRIMARY KEY,  -- unique and NOT NULL by definition
    name VARCHAR(100) NOT NULL
);
```

### Referential Integrity

Referential integrity ensures that a foreign key value in one table always matches an existing primary key value in the referenced table (or is null, if allowed). It prevents "orphan" rows that point to non-existent parent records.

```sql
CREATE TABLE department (
    department_id INT PRIMARY KEY,
    name VARCHAR(100)
);

CREATE TABLE employee (
    employee_id INT PRIMARY KEY,
    department_id INT,
    FOREIGN KEY (department_id) REFERENCES department(department_id)
);
```

### Domain Constraints

A domain constraint restricts the set of valid values a column can hold, based on its data type, length, format, or range (e.g., `age` must be an integer between 0 and 150). It's the most basic form of data validation, enforced at the column level.

### Check Constraints

A `CHECK` constraint enforces a custom boolean condition on column values, rejecting any insert or update that violates it. It's useful for business rules that go beyond simple data types.

```sql
CREATE TABLE product (
    product_id INT PRIMARY KEY,
    price DECIMAL(10,2) CHECK (price > 0),
    discount_pct INT CHECK (discount_pct BETWEEN 0 AND 100)
);
```

### Unique Constraints

A `UNIQUE` constraint ensures no two rows have the same value in a column (or column combination), while — unlike a primary key — still allowing a single null value (in most databases) and permitting multiple unique constraints per table.

```sql
CREATE TABLE user_account (
    id INT PRIMARY KEY,
    email VARCHAR(255) UNIQUE
);
```

### Not Null Constraints

A `NOT NULL` constraint requires that a column always have a value, preventing missing/unknown data for fields that are mandatory for the record to make sense (e.g., a user's `email`).

### Default Constraints

A `DEFAULT` constraint supplies an automatic value for a column when no value is explicitly provided on insert, reducing boilerplate and ensuring sensible baseline values (e.g., `created_at` defaulting to the current timestamp).

```sql
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Referential Actions (On Delete/On Update Cascade)

Referential actions define what happens to dependent (child) rows when the referenced (parent) row is updated or deleted, keeping referential integrity intact automatically instead of leaving orphaned rows or blocking the operation.

```sql
CREATE TABLE employee (
    employee_id INT PRIMARY KEY,
    department_id INT,
    FOREIGN KEY (department_id) REFERENCES department(department_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
```

**Differences: Referential Actions**

| Action | Effect on child rows when parent is deleted/updated |
|---|---|
| `CASCADE` | Child rows are deleted/updated to match the parent change |
| `SET NULL` | Foreign key column in child rows is set to `NULL` |
| `SET DEFAULT` | Foreign key column in child rows is set to its default value |
| `RESTRICT` | Parent change is blocked if matching child rows exist |
| `NO ACTION` | Similar to `RESTRICT`; checked at end of statement/transaction (DB-dependent) |

### Interview Questions

- **Q: What is the difference between a primary key and a unique constraint?**
  A: A primary key uniquely identifies each row, disallows nulls, and a table can have only one; a unique constraint also enforces uniqueness but may allow a null value and a table can have multiple unique constraints.
- **Q: How does referential integrity prevent orphan records?**
  A: By requiring every foreign key value to match an existing primary key in the parent table (or be null), the database rejects inserts/updates that would reference a non-existent parent row.
- **Q: When would you use `ON DELETE SET NULL` instead of `ON DELETE CASCADE`?**
  A: When the child record should still exist after the parent is deleted, but the relationship should be cleared — e.g., an `employee.manager_id` should become null rather than deleting the employee when a manager is removed.
- **Q: Can a CHECK constraint reference another table?**
  A: No, standard `CHECK` constraints can only evaluate expressions using columns within the same row/table; cross-table validation requires triggers or application logic.
- **Q: What's the difference between a domain constraint and a check constraint?**
  A: A domain constraint is the basic type/format/range restriction inherent to a column's data type; a check constraint is a custom boolean rule you explicitly define for more specific business logic.
- **Q: Why might `NOT NULL` and `DEFAULT` be used together on the same column?**
  A: To guarantee the column always has a meaningful value: `DEFAULT` supplies a value automatically when none is given, and `NOT NULL` guards against explicit null values being inserted.
- **Q: What happens if you try to delete a parent row with `ON DELETE RESTRICT` and matching child rows exist?**
  A: The delete is rejected by the database with a constraint violation error, and the parent row remains until the child rows are removed or re-pointed first.

