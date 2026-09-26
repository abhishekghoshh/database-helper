# Relational Database Concepts

## Theory

### Tables

A table (or relation) is the fundamental storage structure in a relational database — a two-dimensional grid of rows and columns representing a set of entities of the same type (e.g., `employees`, `orders`). Each table has a fixed set of named columns with defined data types, and each row represents a single record conforming to that structure.

```sql
CREATE TABLE employees (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    department_id INT
);
```

### Rows (Tuples)

A row, also called a tuple, is a single record in a table — an ordered set of attribute values, one per column. In relational theory, a table is technically a *set* of tuples, meaning duplicate rows shouldn't exist without a distinguishing key, although real-world RDBMS implementations allow duplicates unless constraints prevent it.

### Columns (Attributes)

A column (or attribute) defines a named property shared by every row in a table, along with its data type and constraints (e.g., `NOT NULL`, `UNIQUE`). Columns give tables their structure and determine what kind of data can be stored — for example, `name VARCHAR(100)` or `hire_date DATE`.

### Domains

A domain is the set of all valid, atomic values that an attribute is allowed to take — essentially the data type plus any additional constraints (e.g., `age` must be an integer between 0 and 150). Domains enforce data integrity by rejecting values outside the permitted range or format at the column level.

```sql
ALTER TABLE employees
ADD CONSTRAINT chk_age CHECK (age BETWEEN 18 AND 65);
```

### Keys Overview

Keys are attributes (or sets of attributes) used to uniquely identify rows and to establish relationships between tables. They include primary keys, candidate keys, foreign keys, and others — covered in detail in the "Database Keys" section. Keys are central to enforcing entity and referential integrity in a relational schema.

### Relationships

A relationship represents how rows in one table are associated with rows in another, typically implemented via foreign keys referencing a primary key. Relationships are what let relational databases avoid duplicating data — e.g., an `orders` table references a `customers` table rather than repeating customer details on every order. (Full cardinality types are covered in the "Relationships" section.)

### Cardinality

Cardinality describes the number of related instances between two entities in a relationship — one-to-one, one-to-many, or many-to-many. It also has a second meaning at the column level: the number of distinct values in a column relative to the total rows (e.g., a `gender` column has low cardinality; an `email` column has high cardinality), which matters for indexing strategy.

### Degree of a Relation

The degree of a relation is the number of attributes (columns) it contains. For example, a table with columns `id`, `name`, and `email` has degree 3. This is distinct from the **cardinality of a relation**, which refers to the number of tuples (rows) currently in the table.

### Schema vs Instance

The **schema** is the structural blueprint of the database — table definitions, columns, types, and constraints — and changes infrequently. The **instance** is the actual data present in the database at a specific moment in time, which changes constantly as rows are inserted, updated, or deleted. Think of the schema as the class definition and the instance as the current set of objects.

### Metadata

Metadata is "data about data" — information describing the structure, constraints, and relationships of the database itself, stored in the **system catalog** (or data dictionary). It includes table/column definitions, index information, user privileges, and constraints, and is queried through views like `INFORMATION_SCHEMA` in most SQL databases.

```sql
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_name = 'employees';
```

### Interview Questions

- **Q: What is the difference between a table's schema and its instance?**
  A: The schema is the fixed structural definition (columns, types, constraints); the instance is the actual set of rows present at a given moment, which changes with every DML operation.
- **Q: What's the difference between the degree and cardinality of a relation?**
  A: Degree is the number of columns (attributes); cardinality is the number of rows (tuples) currently stored.
- **Q: Why does column cardinality matter for performance?**
  A: Low-cardinality columns (e.g., booleans) generally benefit less from B-tree indexes since they don't narrow down search results much, while high-cardinality columns (e.g., unique IDs) index very effectively.
- **Q: What is a domain constraint, and how is it enforced in SQL?**
  A: A domain constraint restricts the valid values an attribute can hold; it's enforced via column data types, `CHECK` constraints, and `NOT NULL`/`UNIQUE` clauses.
- **Q: Why is a table considered a "set" of tuples in relational theory, and how does this differ from real-world RDBMS behavior?**
  A: Relational theory disallows duplicate tuples in a set; but most RDBMS implementations permit duplicate rows unless a primary key or unique constraint explicitly forbids them.
- **Q: How would you find all foreign key relationships involving a given table?**
  A: Query the database's metadata/catalog views, e.g., `information_schema.key_column_usage` and `information_schema.table_constraints` in MySQL/Postgres.
- **Q: What's the difference between a relationship and a foreign key?**
  A: A relationship is the logical association between two entities/tables; a foreign key is the physical/implementation mechanism used to enforce that relationship at the database level.
- **Q: Give an example of where metadata would be used in an application.**
  A: An ORM (e.g., Hibernate) reads table/column metadata at startup to map Java classes to database tables automatically.

