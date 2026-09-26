# Data Types

## Numeric Types

Numeric types store integers and decimals with varying range and precision. Choosing the right one balances storage size, precision, and performance.

| Type | Example | Use case |
|---|---|---|
| `SMALLINT` | -32,768 to 32,767 | Small counters, flags |
| `INT`/`INTEGER` | ~-2.1B to 2.1B | General-purpose whole numbers |
| `BIGINT` | ~-9.2 quintillion to 9.2 quintillion | IDs, large counters |
| `DECIMAL(p,s)` / `NUMERIC(p,s)` | exact precision `p`, scale `s` | Currency, financial calculations |
| `FLOAT` / `REAL` / `DOUBLE PRECISION` | approximate, IEEE 754 | Scientific measurements, non-exact math |

```sql
CREATE TABLE invoices (
    id          BIGINT PRIMARY KEY,
    quantity    INT NOT NULL,
    unit_price  NUMERIC(10, 2) NOT NULL,  -- exact: 10 total digits, 2 after decimal
    weight_kg   DOUBLE PRECISION           -- approximate
);
```

**Key gotcha:** Never use `FLOAT`/`DOUBLE` for money. Floating-point types use binary fractions internally and cannot exactly represent values like `0.1`, leading to rounding errors that accumulate (e.g., `0.1 + 0.2 != 0.3` in floating-point arithmetic). Always use `DECIMAL`/`NUMERIC` for currency.

## Character Types

Character types store text data, differing mainly in whether they're fixed-length or variable-length, and whether there's a size cap.

| Type | Description |
|---|---|
| `CHAR(n)` | Fixed-length, space-padded to `n` characters |
| `VARCHAR(n)` | Variable-length, up to `n` characters |
| `TEXT` | Variable-length, unbounded (or very large limit) |

```sql
CREATE TABLE users (
    country_code CHAR(2),        -- always exactly 2 chars, e.g. 'US'
    username     VARCHAR(30),    -- up to 30 chars
    bio          TEXT            -- unbounded free text
);
```

- `CHAR` wastes space with padding but has predictable row size; rarely used except for fixed-format codes (e.g., ISO country codes).
- `VARCHAR` is the most common general-purpose choice.
- `TEXT` (PostgreSQL/MySQL) is ideal for large, unbounded content like descriptions or comments; some databases (older SQL Server) discourage `TEXT` in favor of `VARCHAR(MAX)`.

## Boolean Type

`BOOLEAN` stores `TRUE`, `FALSE`, or `NULL` (representing "unknown"). Not all databases have a native boolean type — MySQL implements `BOOLEAN` as an alias for `TINYINT(1)`, while Oracle has no boolean column type at all (commonly emulated with `CHAR(1)` or `NUMBER(1)`).

```sql
CREATE TABLE features (
    id         INT PRIMARY KEY,
    is_enabled BOOLEAN NOT NULL DEFAULT FALSE
);

SELECT * FROM features WHERE is_enabled = TRUE;
SELECT * FROM features WHERE is_enabled;  -- equivalent shorthand
```

**Gotcha:** Because SQL uses three-valued logic (`TRUE`/`FALSE`/`UNKNOWN`), a nullable boolean column compared with `= TRUE` will exclude `NULL` rows — you must explicitly handle `IS NULL` if that matters.

## Date and Time Types

| Type | Stores | Notes |
|---|---|---|
| `DATE` | Year, month, day | No time component |
| `TIME` | Hour, minute, second (+fraction) | No date component |
| `TIMESTAMP` | Date + time | No timezone awareness by default |
| `TIMESTAMPTZ` / `TIMESTAMP WITH TIME ZONE` | Date + time + timezone | Stored normalized to UTC internally |
| `INTERVAL` | A span of time (e.g., `3 days`) | PostgreSQL/Oracle specific |

```sql
CREATE TABLE events (
    id          INT PRIMARY KEY,
    event_date  DATE,
    starts_at   TIMESTAMPTZ NOT NULL,
    duration    INTERVAL
);

INSERT INTO events VALUES (1, '2024-06-01', '2024-06-01 09:00:00+00', '2 hours');

SELECT starts_at + duration AS ends_at FROM events;
```

**Best practice:** Always store timestamps as `TIMESTAMPTZ`/UTC in the database and convert to local time zone only in the presentation layer — this avoids ambiguity across daylight saving transitions and multi-region deployments.

## UUID

A UUID (Universally Unique Identifier) is a 128-bit value, typically represented as a 36-character hyphenated hex string (e.g., `550e8400-e29b-41d4-a716-446655440000`), used as a globally unique identifier without requiring a central authority to coordinate uniqueness.

```sql
CREATE TABLE sessions (
    id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),  -- PostgreSQL (pgcrypto)
    user_id BIGINT NOT NULL
);
```

| Aspect | Auto-increment INT/BIGINT | UUID |
|---|---|---|
| Uniqueness scope | Per-table (or per-sequence) | Globally unique |
| Predictability | Sequential, guessable | Random, harder to enumerate |
| Index locality | Sequential, index-friendly | Random insertion can fragment B-tree indexes |
| Storage size | 4-8 bytes | 16 bytes |
| Merging data across DBs/shards | Risk of collisions | Safe (practically collision-free) |

**Real-life scenario:** Distributed systems generating IDs independently on multiple nodes (e.g., offline mobile clients later syncing to a central server) use UUIDs to avoid ID collisions, whereas a single-writer monolithic system might prefer sequential BIGINT IDs for index performance.

## JSON / JSONB (Overview)

Modern relational databases support storing semi-structured JSON documents in a column, blending relational and document-model flexibility.

- `JSON` (PostgreSQL/MySQL): stores an exact text representation of the JSON input, preserving formatting/key order; re-parsed on every access.
- `JSONB` (PostgreSQL only): stores a decomposed, binary format — faster to query and index, but doesn't preserve exact text formatting or duplicate keys.

```sql
CREATE TABLE products (
    id         INT PRIMARY KEY,
    attributes JSONB
);

INSERT INTO products VALUES (1, '{"color": "red", "size": "M", "tags": ["sale", "new"]}');

SELECT attributes->>'color' AS color
FROM products
WHERE attributes @> '{"size": "M"}';

CREATE INDEX idx_products_attrs ON products USING GIN (attributes);
```

**Real-life scenario:** An e-commerce `products` table where each category has wildly different attributes (shoe size vs. screen resolution) can store category-specific attributes in a `JSONB` column instead of maintaining dozens of nullable columns or an EAV (entity-attribute-value) table.

## Binary Data Types

Binary types store raw byte sequences — images, files, encrypted blobs — rather than human-readable text.

| Type | Description |
|---|---|
| `BLOB` (MySQL/Oracle) | Binary Large Object, unbounded raw bytes |
| `BYTEA` (PostgreSQL) | Variable-length byte array |
| `VARBINARY(n)` (SQL Server/MySQL) | Variable-length binary, up to `n` bytes |

```sql
CREATE TABLE documents (
    id       INT PRIMARY KEY,
    file_data BYTEA  -- PostgreSQL
);
```

**Trade-off:** Storing large binary files directly in the database simplifies transactional consistency (file and metadata committed together) but bloats the database size and backup time; a common alternative is storing files in object storage (e.g., S3) and keeping only a reference URL/key in the database.

#### Interview Questions

1. **Why should you never use `FLOAT`/`DOUBLE` for currency values?**
   Floating-point types represent numbers in binary fractions, which cannot exactly represent many decimal values (e.g., `0.1`). This introduces rounding errors that compound across many operations, making totals inaccurate. `DECIMAL`/`NUMERIC` types store exact base-10 values with defined precision and scale, which is essential for financial correctness.
2. **What's the practical difference between `CHAR(n)` and `VARCHAR(n)`?**
   `CHAR(n)` is fixed-length and pads shorter values with spaces to always occupy `n` characters, giving predictable row sizes but wasting space; `VARCHAR(n)` stores only the actual characters used (plus a small length prefix), saving space for variable-length data. `CHAR` is mainly useful for fixed-format codes like ISO country/currency codes.
3. **Why is it recommended to store timestamps as UTC (`TIMESTAMPTZ`) rather than local time?**
   Storing local time without a timezone is ambiguous (which timezone? did DST apply?) and breaks when servers/users span multiple regions. Storing as UTC provides a single unambiguous point in time; conversion to a user's local timezone should happen at the display/presentation layer.
4. **When would you choose a UUID primary key over an auto-incrementing integer, and what's the downside?**
   UUIDs are ideal when IDs must be generated independently across multiple nodes/services without coordination (distributed systems, offline-first apps, merging data from multiple databases) since collisions are practically impossible. The downside is worse index locality — random UUID values inserted into a B-tree index cause page splits and fragmentation, and they consume more storage (16 bytes vs 4-8 bytes) than integers.
5. **What's the difference between `JSON` and `JSONB` in PostgreSQL?**
   `JSON` stores the exact input text and re-parses it on every query, preserving whitespace/key order/duplicate keys. `JSONB` stores a parsed, binary decomposed format that's faster to query and supports indexing (e.g., GIN indexes), but normalizes the data (removes duplicate keys, doesn't preserve formatting). `JSONB` is almost always preferred unless exact text preservation is required.
6. **Why might you avoid storing large binary files (like PDFs or images) directly in a database column?**
   Storing large BLOBs bloats table/database size, slows down backups and replication, and can degrade cache efficiency since the buffer pool has to hold large binary payloads alongside regular row data. A common pattern is storing files in dedicated object storage (e.g., S3) and keeping just a reference/URL in the relational table.
