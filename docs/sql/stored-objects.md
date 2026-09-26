# Stored Database Objects

Spring Data JPA applications are usually built around the ORM owning schema logic in Java, so stored procedures, functions, and triggers are used sparingly. Still, interviewers expect awareness of what these objects are, when teams reach for them anyway (bulk data migrations, auditing, cross-application business rules), and the trade-offs versus keeping logic in the application layer.

## Stored Procedures (Overview)

A stored procedure is a named, precompiled block of SQL (and procedural logic — loops, conditionals, variables) stored in the database and invoked with `CALL`. Procedures can perform multiple statements, including inserts/updates/deletes across several tables, and don't have to return a value.

```sql
CREATE PROCEDURE transfer_funds(
    sender_id BIGINT,
    receiver_id BIGINT,
    amount NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE accounts SET balance = balance - amount WHERE id = sender_id;
    UPDATE accounts SET balance = balance + amount WHERE id = receiver_id;

    IF (SELECT balance FROM accounts WHERE id = sender_id) < 0 THEN
        RAISE EXCEPTION 'Insufficient funds for account %', sender_id;
    END IF;
END;
$$;

CALL transfer_funds(1, 2, 250.00);
```

Stored procedures are attractive when an operation must be atomic, reused by multiple applications/languages, and should avoid the round-trip overhead of several separate statements. The downside is that business logic becomes split between the database and the application, harder to version-control alongside code, and harder to unit test with ordinary Java tooling.

## Functions

A SQL function is similar to a stored procedure but is designed to compute and return a value (scalar, row, or set of rows) and can be used directly inside a query, e.g. in a `SELECT` list or `WHERE` clause — something a procedure cannot do.

```sql
CREATE FUNCTION full_name(first_name VARCHAR, last_name VARCHAR)
RETURNS VARCHAR
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT first_name || ' ' || last_name;
$$;

SELECT id, full_name(first_name, last_name) AS display_name
FROM employees;
```

Functions are commonly used for reusable computed expressions, custom validation logic referenced from `CHECK` constraints, or encapsulating a complex calculation (like tax or discount rules) so it isn't duplicated across many queries.

## Triggers (Overview)

A trigger is a piece of procedural code the database executes automatically in response to an `INSERT`, `UPDATE`, or `DELETE` on a table — `BEFORE` or `AFTER` the operation, and either once per statement or once per row. Triggers are how databases implement things like automatic `updated_at` timestamps or audit logging that must happen no matter which application or tool modifies the data.

```sql
CREATE TABLE employees (
    id BIGSERIAL PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_employees_updated_at
BEFORE UPDATE ON employees
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
```

Triggers are powerful but easy to overuse: because they fire implicitly, they can make debugging harder ("why did this column change? — a trigger did it") and can hide business logic from developers who only look at the application code. In a Spring JPA codebase, an `@PrePersist`/`@PreUpdate` entity listener is often preferred for this exact scenario because it keeps the logic visible in Java, but a database trigger is the safer choice when *every* writer to the table (including other services, ETL jobs, or manual `psql` sessions) must be guaranteed to trigger the behavior.

## Sequences

A sequence is a standalone database object that generates a series of unique numbers, most commonly used to back auto-incrementing primary keys. `BIGSERIAL`/`SERIAL` columns in PostgreSQL are actually shorthand for "create a sequence and default the column to `nextval()` on it."

```sql
CREATE SEQUENCE order_number_seq
    START WITH 1000
    INCREMENT BY 1;

SELECT nextval('order_number_seq'); -- 1000
SELECT nextval('order_number_seq'); -- 1001

CREATE TABLE orders (
    id BIGINT PRIMARY KEY DEFAULT nextval('order_number_seq'),
    customer_id BIGINT NOT NULL
);
```

Sequences matter directly to Spring Data JPA: `@GeneratedValue(strategy = GenerationType.SEQUENCE)` maps an entity's identifier to a database sequence, and Hibernate can even pre-allocate blocks of sequence values (`@SequenceGenerator(allocationSize = ...)`) to reduce round-trips when inserting many entities in a batch.

```java
@Entity
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "order_seq")
    @SequenceGenerator(name = "order_seq", sequenceName = "order_number_seq", allocationSize = 50)
    private Long id;
}
```

#### Interview Questions

1. **What is the key functional difference between a stored procedure and a function?**
   A function must return a value and can be called from within a `SELECT` statement or expression; a procedure is invoked with `CALL`, may perform multiple independent operations (including transactional control in some databases), and does not need to return a value.
2. **Why might a team prefer a database trigger over a JPA entity listener (`@PrePersist`/`@PreUpdate`) for auditing?**
   A trigger fires for any write to the table regardless of which application, service, or tool performs it (including raw SQL scripts or other microservices sharing the database), guaranteeing consistent behavior. A JPA listener only fires for writes that go through that specific application's entity manager.
3. **What is a downside of relying heavily on triggers for business logic?**
   Logic becomes implicit and scattered outside the application codebase, making it harder to trace, test, and version alongside the rest of the code — a developer reading the Java code may not realize a column is being modified by a trigger.
4. **How does `GenerationType.SEQUENCE` with `allocationSize` improve insert performance in Hibernate?**
   Instead of calling the database sequence once per entity to get the next ID, Hibernate can request and cache a block of N sequence values (`allocationSize`) in one round trip, then hand them out to new entities locally — dramatically reducing database round-trips for bulk inserts compared to `GenerationType.IDENTITY`.
5. **Why can `GenerationType.IDENTITY` hurt JDBC batch insert performance compared to `GenerationType.SEQUENCE`?**
   With `IDENTITY`, the database assigns the primary key only after the row is inserted, so Hibernate must execute (and see the result of) each insert individually to learn the generated ID, which effectively disables statement batching. `SEQUENCE` lets Hibernate know the ID before the insert, so multiple inserts can be batched together.
6. **When would you reach for a stored procedure instead of doing the equivalent work in a `@Service` method with multiple JPA repository calls?**
   When the operation needs to be atomic and shared across multiple applications/languages without duplicating logic, or when minimizing network round-trips for a multi-step operation matters more than keeping logic in version-controlled Java code — for example, a nightly batch reconciliation job run directly against the database.
