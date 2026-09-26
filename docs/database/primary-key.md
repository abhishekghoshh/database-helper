# Database Keys


## Youtube

- [Auto-Increment vs UUID Explained in 5 Minutes](https://www.youtube.com/watch?v=JbdvmQ_HgJo)

## Theory

### Primary Key

A primary key is a column (or set of columns) chosen to uniquely identify each row in a table. It must be unique and cannot contain `NULL` values, and a table can have only one primary key (though it may be composite). The DBMS typically creates a unique index automatically on the primary key to enforce this constraint efficiently.

```sql
CREATE TABLE employees (
    id INT PRIMARY KEY,
    name VARCHAR(100)
);
```

### Candidate Key

A candidate key is any minimal set of attributes that could qualify as the primary key — i.e., it uniquely identifies rows and contains no redundant attributes. A table may have multiple candidate keys (e.g., `employee_id` and `ssn` could both uniquely identify an employee), and one of them is chosen as the primary key; the rest become alternate keys.

### Super Key

A super key is any set of attributes that uniquely identifies a row, but unlike a candidate key, it may contain extra, redundant attributes. Every candidate key is a super key, but not every super key is a candidate key (only the *minimal* super keys are candidate keys).

| Key Type | Unique? | Minimal? | Example |
|---|---|---|---|
| Super Key | Yes | Not necessarily | `{id, name}` |
| Candidate Key | Yes | Yes | `{id}` |

### Alternate Key

An alternate key is a candidate key that was **not** chosen as the primary key. If a table has `employee_id` and `email` as candidate keys and `employee_id` is selected as the primary key, then `email` becomes an alternate key — still enforced as unique but not the main identifier.

### Composite Key

A composite key (or compound key) is a primary key made up of two or more columns that together uniquely identify a row, even though no single column does so alone. It's common in junction/associative tables that resolve many-to-many relationships.

```sql
CREATE TABLE enrollments (
    student_id INT,
    course_id INT,
    PRIMARY KEY (student_id, course_id)
);
```

### Foreign Key

A foreign key is a column (or set of columns) in one table that references the primary key (or a unique key) of another table, establishing a link between the two. It enforces **referential integrity** — you cannot insert a foreign key value that doesn't exist in the referenced table, and depending on configuration, deleting a referenced row can cascade, restrict, or nullify dependent rows.

```sql
CREATE TABLE orders (
    id INT PRIMARY KEY,
    customer_id INT,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE CASCADE
);
```

### Natural Key

A natural key is an identifier that has inherent business meaning and exists independently of the database (e.g., a Social Security Number, an ISBN, or an email address). Because natural keys can sometimes change or aren't guaranteed unique across all edge cases, many designs prefer surrogate keys instead.

### Surrogate Key

A surrogate key is an artificially generated identifier with no business meaning — typically an auto-incrementing integer or a UUID — used purely to uniquely identify rows. Surrogate keys are stable (never change even if business data changes) and simplify joins, which is why they're the most common primary key choice in practice.

- **Advantages**: stable, simple, performant for joins/indexing, insulated from business rule changes.
- **Disadvantages**: carries no business meaning, requires an extra uniqueness check (natural key) if business-level duplicates must still be prevented.

### Unique Key

A unique key constraint ensures all values in a column (or column set) are distinct across the table, similar to a primary key, but a table can have multiple unique keys and they **do** allow a single `NULL` value (behavior varies slightly by RDBMS). It's commonly used for attributes like `email` that must be unique but aren't the main identifier.

```sql
ALTER TABLE users
ADD CONSTRAINT uq_email UNIQUE (email);
```

### Interview Questions

- **Q: What is the difference between a primary key and a unique key?**
  A: Both enforce uniqueness, but a table can have only one primary key (which disallows `NULL`), while it can have multiple unique keys (which typically allow one `NULL` value).
- **Q: What is the difference between a candidate key and a super key?**
  A: A candidate key is a minimal unique identifier (no redundant attributes); a super key is any unique identifier, which may include extra unnecessary attributes.
- **Q: Why would you use a composite key instead of a single-column key?**
  A: When no single attribute uniquely identifies a row, but a combination does — e.g., in a many-to-many junction table like `enrollments(student_id, course_id)`.
- **Q: Why prefer a surrogate key over a natural key as a primary key?**
  A: Surrogate keys are immutable and simple (e.g., auto-increment IDs), avoiding problems when natural keys change over time (e.g., a person's email or phone number) or turn out not to be truly unique.
- **Q: What happens if you try to insert a foreign key value that doesn't exist in the parent table?**
  A: The database raises a referential integrity violation error and rejects the insert, unless the constraint is deferred or disabled.
- **Q: What does `ON DELETE CASCADE` do on a foreign key?**
  A: It automatically deletes dependent rows in the child table when the referenced row in the parent table is deleted.
- **Q: Can a foreign key reference a non-primary-key column?**
  A: Yes, as long as the referenced column has a unique constraint or unique index.
- **Q: If a table has both `employee_id` and `ssn` as candidate keys, and `employee_id` is chosen as primary key, what is `ssn` called?**
  A: An alternate key.
- **Q: Is every candidate key also a super key?**
  A: Yes — every candidate key is a super key, but not every super key is a candidate key, since super keys can contain redundant attributes.

