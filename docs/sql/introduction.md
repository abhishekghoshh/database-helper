# Structured Query Language(SQL)


## Theory

Structured data with predefined schema.

**Characteristics:**
- Tables with rows and columns
- ACID compliance
- Relationships (foreign keys)
- SQL query language
- Strong consistency

**Popular Databases:**
- PostgreSQL
- MySQL
- Oracle
- SQL Server
- SQLite

**When to Use:**
- Complex queries and joins
- Transactions required
- Data integrity critical
- Structured data

### SQL Databases: Advantages

```
✓ ACID Guarantees
  - Atomicity: All or nothing transactions
  - Consistency: Data integrity maintained
  - Isolation: Concurrent transactions don't interfere
  - Durability: Committed data persists
  
  Example:
  BEGIN TRANSACTION;
    UPDATE accounts SET balance = balance - 100 WHERE id = 1;
    UPDATE accounts SET balance = balance + 100 WHERE id = 2;
  COMMIT;  ← Both succeed or both fail

✓ Data Integrity
  - Foreign keys enforce relationships
  - Constraints prevent invalid data
  - Triggers for business logic
  - Validation at database level
  
  CREATE TABLE orders (
    user_id INT REFERENCES users(id),  ← Must be valid user
    amount DECIMAL CHECK (amount > 0)  ← Must be positive
  );

✓ Complex Queries
  - JOIN multiple tables
  - Aggregate functions (SUM, AVG, COUNT)
  - Window functions
  - Subqueries
  - CTE (Common Table Expressions)
  
  SELECT u.name, COUNT(o.id) as order_count
  FROM users u
  LEFT JOIN orders o ON u.id = o.user_id
  WHERE u.created_at > '2025-01-01'
  GROUP BY u.name
  HAVING COUNT(o.id) > 5;

✓ Mature Ecosystem
  - 40+ years of development
  - Battle-tested
  - Rich tooling (ORMs, GUI tools, monitoring)
  - Large talent pool
  - Abundant documentation

✓ Standardization
  - SQL is standard (with variations)
  - Portable knowledge
  - Similar syntax across databases
  - Industry best practices

✓ Strong Consistency
  - Always see latest data
  - No eventual consistency issues
  - Predictable behavior
  
✓ Schema Enforcement
  - Data structure defined upfront
  - Type safety
  - Documentation built-in
  - Prevents data corruption
```

### SQL Databases: Disadvantages

```
✗ Scaling Challenges
  - Vertical scaling (bigger machine)
  - Horizontal scaling complex
  - Sharding difficult
  - Distributed joins expensive
  
  Vertical scaling limits:
  - Max: ~96 cores, 2TB RAM
  - Cost: Exponential ($$$$$)
  - Still single point of failure

✗ Schema Rigidity
  - Must define schema upfront
  - Changes require migrations
  - ALTER TABLE can lock table
  - Backwards compatibility needed
  
  Example problem:
  ALTER TABLE users ADD COLUMN preferences JSON;
  → Locks table for minutes on large dataset
  → Downtime or careful planning needed

✗ Performance Issues at Scale
  - Joins slow with large tables
  - Indexes trade-off (faster reads, slower writes)
  - Full table scans costly
  - Locking contention
  
  SELECT * FROM orders o
  JOIN users u ON o.user_id = u.id
  JOIN products p ON o.product_id = p.id;
  
  With millions of rows: seconds or minutes

✗ Limited Horizontal Scaling
  - Read replicas: Yes (easy)
  - Write scaling: No (single primary)
  - Sharding: Possible but complex
  - Cross-shard joins: Expensive

✗ Not Ideal for Unstructured Data
  - JSON/BLOB support limited
  - Hierarchical data awkward
  - Graph relationships inefficient
  
✗ High Operational Overhead
  - Backup/restore complex
  - Index maintenance
  - Query optimization needed
  - Monitoring required
```

### SQL vs NoSQL: The Complete Comparison

| Aspect | SQL | NoSQL |
|--------|-----|-------|
| **Data Model** | Tables, rows, columns | Documents, key-value, graphs, columns |
| **Schema** | Fixed, predefined | Flexible, dynamic |
| **Scaling** | Vertical (scale up) | Horizontal (scale out) |
| **Transactions** | Full ACID | Limited (varies by DB) |
| **Consistency** | Strong | Eventual (usually) |
| **Joins** | Native, efficient | Limited or application-level |
| **Query Language** | SQL (standard) | Varies (no standard) |
| **Use Case** | Complex queries, transactions | High throughput, flexible schema |
| **Examples** | PostgreSQL, MySQL | MongoDB, Cassandra, Redis |
| **Cost at Scale** | High (bigger machines) | Lower (commodity hardware) |
| **Complexity** | Lower (mature tools) | Higher (newer, distributed) |

### When to Choose SQL

```
✓ Financial Applications
  - Banking, payments
  - Transactions critical
  - ACID required
  - Data integrity paramount

✓ ERP / CRM Systems
  - Complex relationships
  - Multi-table joins
  - Structured workflows
  - Reporting requirements

✓ E-commerce
  - Inventory management
  - Order processing
  - Consistent pricing
  - Cannot oversell

✓ Traditional Business Apps
  - HR systems
  - Accounting software
  - Booking systems
  - Reservation systems

✓ Analytics / Reporting
  - Complex aggregations
  - Historical data analysis
  - Business intelligence
  - Data warehousing
```

### Alternatives to Traditional SQL

**1. NewSQL (Distributed SQL)**
```
Databases: CockroachDB, Google Spanner, YugabyteDB

What it solves:
  ✓ SQL interface (familiar)
  ✓ ACID transactions (like SQL)
  ✓ Horizontal scaling (like NoSQL)
  
  "Best of both worlds"

Advantages over traditional SQL:
  + Scales horizontally
  + Multi-region support
  + High availability built-in
  + Still ACID compliant
  + SQL compatible

Disadvantages:
  - Higher latency (distributed consensus)
  - More complex operations
  - Less mature
  - Expensive (often)

When to use:
  → Need SQL + horizontal scaling
  → Global distribution required
  → Can afford latency trade-off

Example: CockroachDB
  CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT
  );
  
  → Automatically distributed across regions
  → ACID transactions across globe
```

**2. Time-Series Databases**
```
Databases: InfluxDB, TimescaleDB, Prometheus

What it solves:
  ✓ Optimized for time-series data
  ✓ High write throughput
  ✓ Automatic downsampling
  ✓ Time-based queries

Advantages over SQL:
  + Much faster for time-series
  + Compression (10-100x)
  + Built-in retention policies
  + Continuous aggregates

When to use:
  → Metrics / monitoring
  → IoT sensor data
  → Stock prices
  → Application logs

Example: InfluxDB
  INSERT temperature,location=room1 value=23.5
  
  SELECT MEAN(value) FROM temperature
  WHERE time > now() - 1h
  GROUP BY time(5m);
```

**3. NoSQL (Document, Key-Value, etc.)**
```
See detailed NoSQL section below

When NoSQL is better:
  → Flexible schema needed
  → Massive scale (billions of records)
  → Geographic distribution
  → Eventual consistency acceptable
```

**4. Multi-Model Databases**
```
Databases: ArangoDB, OrientDB

What it solves:
  ✓ Document + Graph + Key-Value in one
  ✓ Avoid data duplication across DBs
  ✓ Single query language

When to use:
  → Need multiple data models
  → Want to simplify architecture
  → Can accept trade-offs (jack of all trades)
```
