# Normalization

## Theory

### Data Redundancy

Data redundancy occurs when the same piece of data is stored in multiple places within a database. It typically arises from poor schema design where related facts (e.g., a customer's address) are duplicated across many rows instead of being stored once and referenced. Redundancy wastes storage and, more importantly, creates a risk that copies of the same fact drift out of sync.

**Disadvantages**

- Wasted disk space and larger backups/indexes.
- Increased risk of inconsistent data when one copy is updated but others are not.
- More I/O needed to keep duplicate copies in sync.

### Update Anomalies

An update anomaly happens when a change to a single fact requires updating multiple rows because that fact is duplicated. If even one of those rows is missed, the database ends up with contradictory data for what should be a single fact.

For example, if a `student_course` table repeats `instructor_email` on every row for a course, changing the instructor's email requires updating every row for that course — missing one row leaves stale data.

### Insertion Anomalies

An insertion anomaly occurs when it is impossible to add a new fact to the database without also supplying unrelated data, usually because two independent facts are combined into one table. For example, if `course` details only exist inside a `student_enrollment` table, a new course cannot be recorded until at least one student enrolls in it.

### Deletion Anomalies

A deletion anomaly occurs when removing a row unintentionally destroys other useful information that happened to be stored in that same row. For example, if the only student enrolled in a course drops it and their row is deleted, information about the course itself (e.g., its title or credits) may be lost along with it.

### Functional Dependency

A functional dependency `A → B` means that for any two rows, if the values of attribute (or attribute set) `A` are equal, the values of `B` must also be equal — `B` is fully determined by `A`. Functional dependencies are the foundation used to define and detect normal forms.

```sql
-- Example: employee_id determines employee_name and department_id
-- employee_id -> employee_name
-- employee_id -> department_id
SELECT employee_id, employee_name, department_id FROM employee;
```

### Partial Dependency

A partial dependency exists when a non-prime attribute (one not part of any candidate key) depends on only *part* of a composite candidate key, rather than the whole key. This is only possible when the primary key has more than one column, and it is the specific defect that Second Normal Form (2NF) eliminates.

### Transitive Dependency

A transitive dependency exists when a non-prime attribute depends on another non-prime attribute, rather than depending directly on the candidate key (i.e., `Key → A → B`, so `Key → B` only indirectly). Third Normal Form (3NF) removes transitive dependencies.

### 1NF

First Normal Form requires that every column hold a single, atomic value (no repeating groups or arrays) and that each row be uniquely identifiable. A table storing a comma-separated list of phone numbers in one column violates 1NF.

```sql
-- Violates 1NF: phones column holds multiple values
-- customer(id, name, phones)  -- phones = '555-1111,555-2222'

-- 1NF fix: one phone per row
-- customer_phone(customer_id, phone)
```

### 2NF

Second Normal Form requires the table to be in 1NF and have no partial dependencies — every non-prime attribute must depend on the *entire* composite primary key, not just part of it.

```sql
-- Violates 2NF (composite key: order_id + product_id)
-- order_item(order_id, product_id, product_name, quantity)
-- product_name depends only on product_id, not the full key

-- 2NF fix: split out the partial dependency
-- product(product_id, product_name)
-- order_item(order_id, product_id, quantity)
```

### 3NF

Third Normal Form requires the table to be in 2NF and have no transitive dependencies — every non-key attribute must depend directly on the primary key, not on another non-key attribute.

```sql
-- Violates 3NF: zip_code -> city, so city is transitively dependent on employee_id
-- employee(employee_id, zip_code, city)

-- 3NF fix
-- employee(employee_id, zip_code)
-- zip_lookup(zip_code, city)
```

### BCNF

Boyce-Codd Normal Form is a stricter version of 3NF: for every non-trivial functional dependency `A → B`, `A` must be a superkey. It resolves anomalies that can remain in 3NF when a table has multiple overlapping candidate keys.

**Differences: 1NF vs 2NF vs 3NF vs BCNF**

| Normal Form | Requirement | Eliminates |
|---|---|---|
| 1NF | Atomic column values, unique rows | Repeating groups |
| 2NF | 1NF + no partial dependency | Partial dependency on composite key |
| 3NF | 2NF + no transitive dependency | Transitive dependency between non-key attributes |
| BCNF | Every determinant is a candidate key | Anomalies from overlapping candidate keys |

### 4NF (Overview)

Fourth Normal Form builds on BCNF by eliminating multivalued dependencies — cases where one attribute has multiple independent values unrelated to another multivalued attribute in the same table (e.g., an employee's skills and the languages they speak stored in one table, producing a cross-product of rows). The fix is to split the independent multivalued facts into separate tables.

### 5NF (Overview)

Fifth Normal Form (Project-Join Normal Form) addresses join dependencies: a table should not be decomposable into smaller tables that, when joined back together, could reconstruct extra spurious rows not implied by the candidate keys. It matters mainly for tables modeling complex many-to-many-to-many relationships and is rarely a practical concern outside advanced schema design.

### Denormalization

Denormalization is the deliberate introduction of redundancy into a normalized schema, typically to improve read performance by reducing the number of joins needed for common queries (e.g., in reporting or analytics systems).

**Advantages**

- Fewer joins, faster reads for read-heavy workloads.
- Simpler queries for reporting/analytics.

**Disadvantages**

- Reintroduces update anomalies and redundancy risk.
- More complex write logic to keep duplicated data consistent.
- Larger storage footprint.

### Interview Questions

- **Q: Why is normalization important in database design?**
  A: It removes redundancy and prevents update, insertion, and deletion anomalies by ensuring each fact is stored in exactly one place, at the cost of requiring more joins for reads.
- **Q: Given `Order(order_id, product_id, product_name, customer_id, customer_name)`, normalize this table to 3NF.**
  A: Split into `Order(order_id, product_id, customer_id)`, `Product(product_id, product_name)`, and `Customer(customer_id, customer_name)` — `product_name` and `customer_name` are transitively/partially dependent, not on the full order key.
- **Q: What is the difference between a partial dependency and a transitive dependency?**
  A: A partial dependency is a non-key attribute depending on part of a composite key; a transitive dependency is a non-key attribute depending on another non-key attribute rather than the key directly.
- **Q: Can a table be in 3NF but not in BCNF?**
  A: Yes — this happens when a table has multiple overlapping candidate keys and a determinant of a dependency is a candidate key but not a superkey; 3NF permits this, BCNF does not.
- **Q: Why would you deliberately denormalize a database?**
  A: To optimize read-heavy workloads (e.g., dashboards, reporting) by avoiding expensive joins, accepting some redundancy and write complexity in exchange for query speed.
- **Q: What is an insertion anomaly? Give an example.**
  A: It's the inability to insert a fact without an unrelated fact also being present, e.g., not being able to add a new department until at least one employee is assigned to it, if department and employee data are combined in one table.
- **Q: How do you detect functional dependencies in a real schema?**
  A: By analyzing business rules and data — checking whether, for any two rows with the same value of `A`, `B` is always the same. It's typically inferred from domain requirements rather than derived purely from sample data.
- **Q: When would 4NF or 5NF actually matter in practice?**
  A: When a table stores multiple independent multivalued facts (4NF) or complex many-to-many-to-many relationships that could produce spurious joins (5NF) — otherwise most production schemas stop at 3NF/BCNF for practicality.

