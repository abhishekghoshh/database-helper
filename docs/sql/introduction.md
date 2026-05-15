# Structured Query Language(SQL)


## Theory

SQL (Structured Query Language) is the standard language for managing and querying **relational databases**. Relational databases organize data into **tables** (relations) with rows (tuples) and columns (attributes), connected through **foreign keys**. Invented at IBM in the 1970s by Edgar F. Codd's relational model, SQL databases remain the backbone of most business applications.

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Relational Model                                  │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Table: users                     Table: orders                      │
│  ┌────┬─────────┬──────────────┐  ┌────┬─────────┬────────┬───────┐│
│  │ id │  name   │    email     │  │ id │ user_id │ amount │ date  ││
│  ├────┼─────────┼──────────────┤  ├────┼─────────┼────────┼───────┤│
│  │  1 │ Alice   │ alice@co.com │  │ 10 │    1    │ 150.00 │ 01-15 ││
│  │  2 │ Bob     │ bob@co.com   │  │ 11 │    1    │  45.99 │ 02-03 ││
│  │  3 │ Charlie │ charlie@co   │  │ 12 │    3    │ 299.00 │ 02-10 ││
│  └────┴─────────┴──────────────┘  └────┴────┬────┴────────┴───────┘│
│       ▲ Primary Key                         │ Foreign Key           │
│       └─────────────────────────────────────┘ (REFERENCES users.id) │
│                                                                      │
│  Relationship:  users 1 ──── * orders  (one-to-many)                │
│  Query:         SELECT * FROM users JOIN orders ON users.id =       │
│                 orders.user_id                                       │
└──────────────────────────────────────────────────────────────────────┘
```

**Characteristics:**

- **Tables with rows and columns** — Data is organized into predefined 2D structures
- **ACID compliance** — Guarantees data correctness even during failures
- **Relationships (foreign keys)** — Tables are connected via referential integrity constraints
- **SQL query language** — Declarative language: you say *what* you want, not *how* to get it
- **Strong consistency** — Every read returns the most recent write
- **Schema-on-write** — Data structure is validated *before* insertion

**How SQL Databases Store Data Internally:**

```
                    ┌────────────────────────────┐
                    │       SQL Query             │
                    │  SELECT * FROM users        │
                    │  WHERE age > 25             │
                    └────────────┬───────────────┘
                                 │
                    ┌────────────▼───────────────┐
                    │      Query Parser          │
                    │  Syntax check, AST build   │
                    └────────────┬───────────────┘
                                 │
                    ┌────────────▼───────────────┐
                    │     Query Optimizer        │
                    │  Choose best execution     │
                    │  plan (index scan vs       │
                    │  sequential scan vs        │
                    │  bitmap scan)              │
                    └────────────┬───────────────┘
                                 │
                    ┌────────────▼───────────────┐
                    │     Execution Engine       │
                    └────────────┬───────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                  ▼
     ┌──────────────┐  ┌──────────────┐   ┌──────────────┐
     │ Buffer Pool  │  │   WAL (Write │   │   Indexes    │
     │ (Cache in    │  │   Ahead Log) │   │  (B-Tree,    │
     │  memory)     │  │              │   │   Hash,      │
     │              │  │  Ensures     │   │   GIN, GiST) │
     │  Hot data    │  │  durability  │   │              │
     │  stays in    │  │  before      │   │  Speed up    │
     │  RAM         │  │  writing to  │   │  lookups     │
     └──────────────┘  │  data files  │   └──────────────┘
                       └──────────────┘
                              │
                       ┌──────▼──────┐
                       │  Data Files │
                       │  (on disk)  │
                       │  Pages/     │
                       │  Blocks     │
                       └─────────────┘
```

**Popular Databases — When to pick which:**

| Database | Best For | Key Strength | License |
|----------|----------|-------------|---------|
| **PostgreSQL** | General purpose, complex queries | Most feature-rich, extensible | Open Source (PostgreSQL License) |
| **MySQL** | Web applications, read-heavy | Simple, fast reads, huge ecosystem | Open Source (GPL) / Commercial |
| **Oracle** | Enterprise, mission-critical | Advanced features, RAC clustering | Commercial ($$$) |
| **SQL Server** | Microsoft/.NET ecosystem | Integration with Azure/Windows | Commercial / Express (free) |
| **SQLite** | Embedded, mobile, testing | Zero-config, single file, serverless | Public Domain |
| **MariaDB** | MySQL alternative | MySQL fork with extra features | Open Source (GPL) |

**When to Use SQL:**

- Complex queries with multiple JOINs
- Transactions required (money, inventory, bookings)
- Data integrity is critical (healthcare, finance, legal)
- Structured, well-defined data
- Ad-hoc reporting and analytics
- Team already knows SQL

### SQL Databases: Advantages

#### ✓ ACID Guarantees

ACID is the gold standard for data reliability. Every SQL transaction provides these four guarantees:

```
┌──────────────────────────────────────────────────────────────────────┐
│                         ACID Properties                              │
├────────────────┬─────────────────────────────────────────────────────┤
│                │                                                     │
│  Atomicity     │  All operations in a transaction succeed or ALL     │
│                │  fail. No partial updates ever.                     │
│                │                                                     │
│  Consistency   │  Database moves from one valid state to another.    │
│                │  All constraints, triggers, and rules are enforced. │
│                │                                                     │
│  Isolation     │  Concurrent transactions don't see each other's     │
│                │  uncommitted changes. As if running sequentially.   │
│                │                                                     │
│  Durability    │  Once committed, data survives crashes, power       │
│                │  failures, and disk corruption (via WAL).           │
│                │                                                     │
└────────────────┴─────────────────────────────────────────────────────┘
```

**Bank transfer example — Atomicity in action:**

```sql
-- Transfer $500 from Alice to Bob
BEGIN TRANSACTION;

  -- Debit Alice (fails if insufficient funds due to CHECK constraint)
  UPDATE accounts SET balance = balance - 500
  WHERE id = 1 AND balance >= 500;

  -- Credit Bob
  UPDATE accounts SET balance = balance + 500
  WHERE id = 2;

  -- Log the transfer
  INSERT INTO transfers (from_id, to_id, amount, created_at)
  VALUES (1, 2, 500, NOW());

COMMIT;
-- ALL three operations succeed together, or NONE of them happen.
-- If the server crashes between the UPDATE and INSERT → entire
-- transaction is rolled back. Alice keeps her $500.
```

**Isolation levels — controlling concurrency trade-offs:**

```sql
-- PostgreSQL: Set isolation level per transaction
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  -- Strongest: transactions behave as if executed one at a time
  -- Slowest but safest — prevents all anomalies
  SELECT balance FROM accounts WHERE id = 1;
  UPDATE accounts SET balance = balance - 100 WHERE id = 1;
COMMIT;
```

```
Isolation Level      Dirty Read  Non-Repeatable Read  Phantom Read  Performance
──────────────────   ──────────  ───────────────────  ────────────  ───────────
READ UNCOMMITTED     Possible    Possible             Possible      Fastest
READ COMMITTED       ✗ No       Possible             Possible      Fast
REPEATABLE READ      ✗ No       ✗ No                Possible      Medium
SERIALIZABLE         ✗ No       ✗ No                ✗ No          Slowest

PostgreSQL default: READ COMMITTED
MySQL (InnoDB) default: REPEATABLE READ

Dirty Read:           Reading uncommitted data from another transaction
Non-Repeatable Read:  Same query returns different data within one transaction
Phantom Read:         New rows appear between queries in one transaction
```

**Durability via Write-Ahead Logging (WAL):**

```
How WAL prevents data loss:

1. Transaction starts
2. Changes written to WAL (append-only log) on disk  ← FIRST
3. Changes applied to in-memory buffer pool
4. COMMIT: WAL entry marked as committed
5. Later: dirty pages flushed from buffer pool to data files (checkpoint)

If crash happens AFTER step 4:
  → WAL replayed on restart → data recovered ✓

If crash happens BEFORE step 4:
  → Uncommitted WAL entries discarded → no partial data ✓

           Write Path:
           ┌────────┐     ┌──────────┐     ┌───────────┐
           │ Client │────▶│ WAL Log  │────▶│ Buffer    │
           │ COMMIT │     │ (on disk)│     │ Pool (RAM)│
           └────────┘     └──────────┘     └─────┬─────┘
                                                  │ Async
                                           ┌──────▼──────┐
                                           │  Data Files  │
                                           │  (on disk)   │
                                           └──────────────┘
```

---

#### ✓ Data Integrity

SQL databases enforce data correctness at the **database level** — not in application code. This means bad data is rejected regardless of which application or script inserts it.

**Comprehensive constraint example:**

```sql
-- A fully constrained schema for an e-commerce system
CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    email       VARCHAR(255) NOT NULL UNIQUE,
    name        VARCHAR(100) NOT NULL,
    age         INT CHECK (age >= 13 AND age <= 150),
    status      VARCHAR(20) DEFAULT 'active' 
                CHECK (status IN ('active', 'suspended', 'deleted')),
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE products (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    price       DECIMAL(10,2) NOT NULL CHECK (price > 0),
    stock       INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    category_id INT NOT NULL REFERENCES categories(id)
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    total       DECIMAL(10,2) NOT NULL CHECK (total > 0),
    status      VARCHAR(20) DEFAULT 'pending'
                CHECK (status IN ('pending','confirmed','shipped','delivered','cancelled')),
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE order_items (
    id          SERIAL PRIMARY KEY,
    order_id    INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  INT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity    INT NOT NULL CHECK (quantity > 0),
    unit_price  DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),
    UNIQUE(order_id, product_id)  -- Can't add same product twice to one order
);
```

**What the database prevents automatically:**

```
Attempt                                    Result
─────────────────────────────────────────  ─────────────────────────────────
INSERT user with duplicate email           ✗ UNIQUE violation
INSERT order for non-existent user         ✗ FOREIGN KEY violation
DELETE user who has orders                 ✗ RESTRICT prevents it
UPDATE product price to -50               ✗ CHECK constraint violation
INSERT order_item with quantity 0         ✗ CHECK constraint violation
DELETE order → auto-deletes order_items   ✓ CASCADE handles it
INSERT user without email                  ✗ NOT NULL violation
```

**Trigger example — Business logic enforced by the database:**

```sql
-- Automatically update product stock when an order item is inserted
CREATE OR REPLACE FUNCTION decrease_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products 
    SET stock = stock - NEW.quantity
    WHERE id = NEW.product_id;
    
    -- Prevent overselling
    IF (SELECT stock FROM products WHERE id = NEW.product_id) < 0 THEN
        RAISE EXCEPTION 'Insufficient stock for product %', NEW.product_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_decrease_stock
AFTER INSERT ON order_items
FOR EACH ROW EXECUTE FUNCTION decrease_stock();

-- Now any insert into order_items automatically adjusts stock
-- and prevents overselling — regardless of which app makes the insert
```

---

#### ✓ Complex Queries

SQL's declarative query language can express incredibly complex data retrieval in a single statement. JOINs, aggregations, window functions, CTEs, and subqueries combine to handle any analytical workload.

**JOIN types visualized:**

```
Table A: users              Table B: orders
┌────┬────────┐             ┌────┬─────────┬────────┐
│ id │ name   │             │ id │ user_id │ amount │
├────┼────────┤             ├────┼─────────┼────────┤
│  1 │ Alice  │             │ 10 │    1    │ 150.00 │
│  2 │ Bob    │             │ 11 │    1    │  45.99 │
│  3 │ Charlie│             │ 12 │    3    │ 299.00 │
│  4 │ Diana  │             │ 13 │   99    │  10.00 │  ← orphan (no user 99)
└────┴────────┘             └────┴─────────┴────────┘

INNER JOIN (only matching rows):
  Alice  → 150.00, 45.99
  Charlie → 299.00
  (Bob, Diana excluded — no orders)
  (Order 13 excluded — no user 99)

LEFT JOIN (all from A + matching from B):
  Alice   → 150.00, 45.99
  Bob     → NULL          ← included with NULL
  Charlie → 299.00
  Diana   → NULL          ← included with NULL

RIGHT JOIN (all from B + matching from A):
  Alice   → 150.00, 45.99
  Charlie → 299.00
  NULL    → 10.00         ← orphan order included

FULL OUTER JOIN (all from both):
  Alice   → 150.00, 45.99
  Bob     → NULL
  Charlie → 299.00
  Diana   → NULL
  NULL    → 10.00

CROSS JOIN (cartesian product):
  Every user × every order = 4 × 4 = 16 rows
```

**Window functions — analytics without GROUP BY:**

```sql
-- Rank employees by salary within each department
SELECT 
    name,
    department,
    salary,
    RANK() OVER (PARTITION BY department ORDER BY salary DESC) as dept_rank,
    salary - LAG(salary) OVER (PARTITION BY department ORDER BY salary DESC) as diff_from_prev,
    AVG(salary) OVER (PARTITION BY department) as dept_avg,
    salary * 100.0 / SUM(salary) OVER (PARTITION BY department) as pct_of_dept_total
FROM employees;

-- Result:
-- name    │ department │ salary │ dept_rank │ diff_from_prev │ dept_avg │ pct_of_dept
-- ────────┼────────────┼────────┼───────────┼────────────────┼──────────┼────────────
-- Alice   │ Engineering│ 150000 │ 1         │ NULL           │ 120000   │ 41.7%
-- Bob     │ Engineering│ 120000 │ 2         │ -30000         │ 120000   │ 33.3%
-- Charlie │ Engineering│  90000 │ 3         │ -30000         │ 120000   │ 25.0%
-- Diana   │ Marketing  │ 110000 │ 1         │ NULL           │  95000   │ 57.9%
-- Eve     │ Marketing  │  80000 │ 2         │ -30000         │  95000   │ 42.1%
```

**CTE (Common Table Expressions) — readable complex queries:**

```sql
-- Find customers who spent more than the average, 
-- their most recent order, and their spending trend
WITH customer_totals AS (
    SELECT 
        user_id,
        COUNT(*) as order_count,
        SUM(total) as total_spent,
        MAX(created_at) as last_order
    FROM orders
    WHERE created_at >= '2025-01-01'
    GROUP BY user_id
),
avg_spending AS (
    SELECT AVG(total_spent) as avg_total FROM customer_totals
),
monthly_trend AS (
    SELECT 
        user_id,
        DATE_TRUNC('month', created_at) as month,
        SUM(total) as monthly_total
    FROM orders
    GROUP BY user_id, DATE_TRUNC('month', created_at)
)
SELECT 
    u.name,
    u.email,
    ct.order_count,
    ct.total_spent,
    ct.last_order,
    ct.total_spent - a.avg_total as above_average_by
FROM customer_totals ct
JOIN users u ON u.id = ct.user_id
CROSS JOIN avg_spending a
WHERE ct.total_spent > a.avg_total
ORDER BY ct.total_spent DESC;
```

**Recursive CTE — hierarchical data (org chart):**

```sql
-- Find all reports under a manager, at any depth
WITH RECURSIVE org_tree AS (
    -- Base case: start with the CEO
    SELECT id, name, manager_id, 0 as depth
    FROM employees
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive case: find direct reports of each person
    SELECT e.id, e.name, e.manager_id, ot.depth + 1
    FROM employees e
    JOIN org_tree ot ON e.manager_id = ot.id
)
SELECT 
    REPEAT('  ', depth) || name as org_chart,
    depth
FROM org_tree
ORDER BY depth, name;

-- Result:
-- org_chart              │ depth
-- ───────────────────────┼──────
-- Alice (CEO)            │ 0
--   Bob (VP Eng)         │ 1
--     Charlie (Sr Dev)   │ 2
--       Eve (Dev)        │ 3
--     Dave (Sr Dev)      │ 2
--   Diana (VP Sales)     │ 1
--     Frank (Sales Rep)  │ 2
```

---

#### ✓ Mature Ecosystem

50+ years of SQL ecosystem means battle-tested tools, massive talent pool, and solutions for virtually every problem.

```
SQL Ecosystem:

Databases:      PostgreSQL, MySQL, Oracle, SQL Server, SQLite, MariaDB
ORMs:           Hibernate (Java), SQLAlchemy (Python), Sequelize (Node.js),
                ActiveRecord (Ruby), Entity Framework (.NET), Prisma (TypeScript)
Migration:      Flyway, Liquibase, Alembic, Rails Migrations, Prisma Migrate
GUI Tools:      pgAdmin, DBeaver, DataGrip, MySQL Workbench, Azure Data Studio
Monitoring:     pg_stat_statements, Performance Schema, Datadog, New Relic
Backup:         pg_dump, mysqldump, WAL archiving, PITR (Point-in-Time Recovery)
Connection:     PgBouncer, ProxySQL, HAProxy (connection pooling)
Replication:    Streaming replication, logical replication, Group Replication
```

---

#### ✓ Standardization

SQL is an ISO/ANSI standard. While databases have vendor-specific extensions, the core language is portable.

```sql
-- This query works on PostgreSQL, MySQL, Oracle, SQL Server, and SQLite:
SELECT 
    department,
    COUNT(*) as employee_count,
    AVG(salary) as avg_salary
FROM employees
WHERE hire_date >= '2024-01-01'
GROUP BY department
HAVING COUNT(*) > 5
ORDER BY avg_salary DESC;

-- ~90% of SQL is portable across databases
-- Vendor-specific features (JSON, arrays, LATERAL JOIN, etc.)
-- are the remaining ~10%
```

---

#### ✓ Strong Consistency

After a write commits, every subsequent read sees that write. No "eventual consistency" surprises.

```
SQL (Strong Consistency):                NoSQL (Eventual Consistency):

T=0: Write balance=100 → DB             T=0: Write balance=100 → Node A
T=1: Read balance → 100 ✓              T=1: Read from Node B → 90 ✗ (stale!)
T=2: Read balance → 100 ✓              T=5: Read from Node B → 100 ✓ (caught up)

User experience:                         User experience:
"I changed my password                   "I changed my password  
 and it works immediately"                but can't log in for 5 seconds!"
```

---

#### ✓ Schema Enforcement

The schema acts as a **contract** — documentation that's always up to date and enforced by the database itself.

```sql
-- The schema IS your documentation
\d orders
                    Table "public.orders"
  Column   │  Type                │ Nullable │ Default
───────────┼──────────────────────┼──────────┼────────────
 id        │ integer              │ not null │ nextval(...)
 user_id   │ integer              │ not null │
 total     │ numeric(10,2)        │ not null │
 status    │ character varying(20)│          │ 'pending'
 created_at│ timestamp            │          │ now()

Indexes:
    "orders_pkey" PRIMARY KEY (id)
    "orders_user_id_idx" btree (user_id)
Foreign-key constraints:
    "orders_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id)
Check constraints:
    "orders_total_check" CHECK (total > 0)
    "orders_status_check" CHECK (status IN ('pending','confirmed','shipped',...))

-- You know EXACTLY what data looks like
-- A new developer reads the schema and understands the domain
-- No surprises, no "what fields does this record have?"
```

### SQL Databases: Disadvantages

#### ✗ Scaling Challenges

SQL databases are designed for **single-server** operation. Scaling beyond one server is possible but complex.

```
Vertical Scaling (scale-up):              Horizontal Scaling (scale-out):
Buy a BIGGER server                       Add MORE servers

  ┌───────────────────┐                   ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
  │                   │                   │ DB  │ │ DB  │ │ DB  │ │ DB  │
  │    MEGA SERVER    │                   │ shard│ │shard│ │shard│ │shard│
  │  128 cores        │                   │  1  │ │  2  │ │  3  │ │  4  │
  │  2TB RAM          │                   └─────┘ └─────┘ └─────┘ └─────┘
  │  $50K/month       │                   
  │                   │                   ✓ NoSQL does this natively
  │  ⚠️ Hard ceiling  │                   ✗ SQL: Must manually partition data
  │  ⚠️ Single point  │                      and rewrite queries. Cross-shard
  │     of failure    │                      JOINs are very expensive.
  └───────────────────┘
  
  PostgreSQL single server realistic limits:
  ├─ Data:     ~5-10 TB comfortably
  ├─ Reads:    ~50K queries/sec (with connection pooling)
  ├─ Writes:   ~10K inserts/sec
  └─ Connections: ~500 concurrent (use PgBouncer for more)
```

**Read scaling with replicas — the easy part:**

```
                    ┌────────────────┐
                    │  Primary (RW)  │
                    │  PostgreSQL    │
                    └───┬───────┬───┘
                  WAL   │       │  WAL
               stream   │       │  stream
                    ┌───▼───┐ ┌─▼──────┐
                    │Replica│ │Replica │
                    │  (RO) │ │  (RO)  │
                    └───────┘ └────────┘
                    
  App reads: Load-balanced across replicas (easy, built-in)
  App writes: All go to Primary (bottleneck)
  
  Replication lag: 10ms-1s typically
  → Reads from replicas may be slightly stale
```

**Write scaling — the hard part (application-level sharding):**

```sql
-- Manual sharding strategy: partition users by ID range
-- Shard 1: users WHERE id BETWEEN 1 AND 1000000
-- Shard 2: users WHERE id BETWEEN 1000001 AND 2000000
-- Shard 3: users WHERE id BETWEEN 2000001 AND 3000000

-- Application must route queries to correct shard:
-- Python pseudocode:
-- def get_shard(user_id):
--     if user_id <= 1_000_000: return shard_1_conn
--     elif user_id <= 2_000_000: return shard_2_conn
--     else: return shard_3_conn

-- Cross-shard query (VERY expensive):
-- "Find all orders from users in NYC" 
-- → Must query ALL shards, merge results in application
-- → No database-level JOIN across shards
```

---

#### ✗ Schema Rigidity

Every change to the data structure requires a migration. On large tables, this can mean downtime.

```sql
-- Adding a column to a small table: instant
ALTER TABLE users ADD COLUMN phone VARCHAR(20);  -- ~1ms

-- Adding a column to a table with 500M rows: DANGEROUS
ALTER TABLE events ADD COLUMN metadata JSONB;
-- PostgreSQL: ~instant (just adds NULL default, no rewrite)
-- MySQL (pre-8.0): Locks table, copies all rows → minutes to HOURS
-- Oracle: Depends on whether default value requires rewrite

-- Changing a column type: always risky on large tables
ALTER TABLE orders ALTER COLUMN amount TYPE NUMERIC(12,4);
-- May require full table rewrite → table locked for minutes
```

**Migration workflow (real-world):**

```
Development → Staging → Production

Step 1: Write migration script
  -- V023__add_user_preferences.sql
  ALTER TABLE users ADD COLUMN preferences JSONB DEFAULT '{}';
  CREATE INDEX idx_users_preferences ON users USING GIN (preferences);

Step 2: Test on staging (with production-sized data)
  → Discovered: index creation takes 45 minutes on 200M rows
  → Solution: CREATE INDEX CONCURRENTLY (non-blocking, PostgreSQL)

Step 3: Deploy during maintenance window or use online migration
  → Zero-downtime approach:
     a) Add column (nullable, no default) ← instant
     b) Deploy code that writes to new + old column
     c) Backfill old rows in batches
     d) Add NOT NULL constraint
     e) Remove old column usage from code
     f) Drop old column

-- vs MongoDB: Just start writing documents with the new field.
--             No migration, no downtime, no batching.
```

---

#### ✗ Performance Issues at Scale

JOINs, full table scans, and lock contention become expensive with large datasets.

**JOIN performance degrades with table size:**

```sql
-- Simple JOIN: fast on small tables, slow on large ones
SELECT o.id, u.name, p.name as product, o.total
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE o.created_at >= '2026-01-01'
ORDER BY o.total DESC
LIMIT 100;

-- Performance by table size:
-- orders: 10K rows   → 5ms    ✓
-- orders: 1M rows    → 200ms  ✓ (with indexes)
-- orders: 100M rows  → 5-30s  ⚠️ (even with indexes)
-- orders: 1B rows    → minutes ✗ (JOINs explode)
```

**Index trade-offs:**

```
Without index:                    With index:
Sequential scan of all rows       B-tree lookup → O(log n)

SELECT * FROM orders              SELECT * FROM orders
WHERE user_id = 12345;            WHERE user_id = 12345;
→ Scans 100M rows: ~30 seconds   → Index scan: ~1ms ✓

BUT indexes have costs:
┌──────────────────────────────────────────────────────────┐
│  Table: orders (100M rows, 20GB)                         │
│  + idx_user_id (B-tree):    3GB    +15% storage          │
│  + idx_created_at (B-tree): 2GB    +10% storage          │
│  + idx_status (B-tree):     1GB    +5% storage           │
│  + idx_search (GIN/tsvector): 5GB  +25% storage          │
│  ─────────────────────────────────────────────────        │
│  Total storage: 31GB (55% overhead!)                     │
│                                                          │
│  Every INSERT must update ALL indexes:                   │
│  Without indexes: 50μs per insert → 20K inserts/sec     │
│  With 4 indexes: 200μs per insert → 5K inserts/sec      │
│  More indexes = slower writes                            │
└──────────────────────────────────────────────────────────┘
```

**Lock contention under high concurrency:**

```
Two transactions updating the same row:

Transaction A:                    Transaction B:
BEGIN;                            BEGIN;
UPDATE accounts                   UPDATE accounts
SET balance = balance - 100       SET balance = balance + 50
WHERE id = 1;                     WHERE id = 1;
-- Acquires row lock ✓            -- BLOCKED! Waiting for A's lock...
...doing more work...             -- ...still waiting...
COMMIT;                           -- Lock released! Now can proceed.
-- Lock released                  COMMIT;

With high concurrency (1000 connections updating popular rows):
  → Lock waits pile up → throughput drops → timeouts → errors
  
Solutions:
  1. Keep transactions short (reduce lock hold time)
  2. Use SELECT ... FOR UPDATE SKIP LOCKED (queue pattern)
  3. Use optimistic locking (version column)
  4. Reduce contention via application design
```

```sql
-- Optimistic locking pattern (avoids row locks)
-- Step 1: Read the row with its version
SELECT id, balance, version FROM accounts WHERE id = 1;
-- Returns: balance=1000, version=5

-- Step 2: Update only if version hasn't changed
UPDATE accounts 
SET balance = 900, version = version + 1
WHERE id = 1 AND version = 5;
-- If 0 rows affected → someone else modified it → retry
```

---

#### ✗ Limited Horizontal Scaling

Read replicas help with read-heavy workloads, but **write scaling** requires sharding — which is complex and breaks many SQL features.

```
What sharding breaks:

┌─── Shard 1 ───┐  ┌─── Shard 2 ───┐  ┌─── Shard 3 ───┐
│ users 1-1M    │  │ users 1M-2M   │  │ users 2M-3M   │
│ orders for    │  │ orders for    │  │ orders for    │
│ these users   │  │ these users   │  │ these users   │
└───────────────┘  └───────────────┘  └───────────────┘

✗ Cross-shard JOINs:
  "Find orders by users in NYC" → user might be on any shard
  Must query all 3 shards and merge results in application

✗ Cross-shard transactions:
  "Transfer money from user on Shard 1 to user on Shard 3"
  Requires 2-phase commit (2PC) — slow and complex

✗ Cross-shard aggregations:
  "SELECT COUNT(*) FROM users" → must sum from all shards

✗ Foreign keys across shards:
  Can't enforce foreign key between Shard 1 users and Shard 2 orders

✗ AUTO_INCREMENT / SERIAL:
  Must use UUIDs or distributed ID generators (Snowflake IDs)

✗ Rebalancing:
  Adding Shard 4 requires moving data from existing shards
```

---

#### ✗ Not Ideal for Unstructured Data

SQL databases work best with structured, tabular data. Hierarchical, graph, or polymorphic data requires workarounds.

```sql
-- Problem: Products with different attributes per category
-- SQL approach 1: Wide table with nullable columns (ugly)
CREATE TABLE products (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200),
    -- Laptop columns
    cpu         VARCHAR(50),    -- NULL for non-laptops
    ram         VARCHAR(20),    -- NULL for non-laptops
    storage     VARCHAR(50),    -- NULL for non-laptops
    -- Clothing columns
    size        VARCHAR(10),    -- NULL for non-clothing
    color       VARCHAR(30),    -- NULL for non-clothing
    material    VARCHAR(50),    -- NULL for non-clothing
    -- Book columns
    author      VARCHAR(100),   -- NULL for non-books
    isbn        VARCHAR(20),    -- NULL for non-books
    pages       INT             -- NULL for non-books
);
-- 100 categories × 10 unique attributes = 1000 mostly-NULL columns!

-- SQL approach 2: EAV (Entity-Attribute-Value) — the "NoSQL in SQL" pattern
CREATE TABLE product_attributes (
    product_id  INT REFERENCES products(id),
    key         VARCHAR(50),
    value       TEXT,
    PRIMARY KEY (product_id, key)
);
-- Flexible but: no type safety, terrible query performance,
-- complex queries to reconstruct a product

-- SQL approach 3: JSONB column (PostgreSQL) — best of both worlds
CREATE TABLE products (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    category    VARCHAR(50) NOT NULL,
    price       DECIMAL(10,2) NOT NULL,
    attributes  JSONB NOT NULL DEFAULT '{}'
);

INSERT INTO products (name, category, price, attributes) VALUES
('MacBook Pro', 'laptop', 2499.99, 
 '{"cpu": "M3 Max", "ram": "36GB", "storage": "1TB SSD"}'),
('T-Shirt', 'clothing', 29.99, 
 '{"size": "L", "color": "blue", "material": "cotton"}');

-- Query JSON fields
SELECT * FROM products 
WHERE attributes->>'cpu' = 'M3 Max';

-- Index JSON for performance
CREATE INDEX idx_products_attrs ON products USING GIN (attributes);
-- ↑ Still not as natural or fast as a document database like MongoDB
```

---

#### ✗ High Operational Overhead

SQL databases require careful tuning, monitoring, and maintenance for production workloads.

```
Ongoing operational tasks:

Daily:
  ├─ Monitor slow queries (pg_stat_statements)
  ├─ Check replication lag
  ├─ Verify backups completed
  └─ Watch connection pool utilization

Weekly:
  ├─ VACUUM / ANALYZE (PostgreSQL) — reclaim dead tuples
  ├─ Review query plans for regressions
  └─ Check index usage (drop unused indexes)

Monthly:
  ├─ Review table bloat
  ├─ Test backup restoration (PITR)
  ├─ Capacity planning
  └─ Security patches

Incident scenarios:
  ├─ Long-running query holding locks → kill it
  ├─ Replication lag > 30s → investigate network/disk
  ├─ Connection pool exhausted → tune PgBouncer
  ├─ Disk space filling → VACUUM FULL or archive
  └─ Failover needed → promote replica to primary
```

```sql
-- PostgreSQL: Find slow queries
SELECT 
    query,
    calls,
    mean_exec_time::numeric(10,2) as avg_ms,
    total_exec_time::numeric(10,2) as total_ms,
    rows
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Find unused indexes (wasting disk and slowing writes)
SELECT 
    schemaname, tablename, indexname,
    idx_scan as times_used,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indexrelid NOT IN (
    SELECT indexrelid FROM pg_constraint WHERE contype = 'p'  -- Keep primary keys
)
ORDER BY pg_relation_size(indexrelid) DESC;

-- Check table bloat (dead rows from updates/deletes)
SELECT 
    relname as table,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows,
    round(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 1) as dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

### SQL vs NoSQL: The Complete Comparison

| Aspect | SQL (Relational) | NoSQL (Non-Relational) |
|--------|------------------|------------------------|
| **Data Model** | Tables, rows, columns | Documents, key-value, graphs, columns |
| **Schema** | Fixed, predefined (schema-on-write) | Flexible, dynamic (schema-on-read) |
| **Scaling** | Vertical (scale up) | Horizontal (scale out) |
| **Transactions** | Full multi-table ACID | Limited (single-doc or none) |
| **Consistency** | Strong (always latest data) | Eventual or tunable (BASE) |
| **Joins** | Native, efficient (O(n log n)) | Limited or application-level |
| **Query Language** | SQL (ISO standard) | Varies — MQL, CQL, Cypher, etc. |
| **Normalization** | Normalized (3NF, minimize duplication) | Denormalized (duplicate for speed) |
| **Writes** | Moderate (~10K/sec single node) | Very high (~100K+/sec per node) |
| **Ad-hoc Queries** | Excellent (query any way) | Must design access patterns upfront |
| **Schema Migration** | ALTER TABLE (can be slow/risky) | No migration needed |
| **Data Integrity** | FK constraints, CHECK, triggers | Application-level enforcement |
| **Tooling Maturity** | 50+ years, very mature | 15+ years, growing fast |
| **Talent Pool** | Very large (most devs know SQL) | Smaller, more specialized |
| **Cost at Scale** | High (big servers + licenses) | Lower (commodity hardware, open source) |
| **Examples** | PostgreSQL, MySQL, Oracle, SQL Server | MongoDB, Cassandra, Redis, Neo4j, DynamoDB |
| **Best For** | Banking, ERP, CRM, e-commerce | Social media, IoT, caching, real-time |

**Same application — SQL vs NoSQL data modeling:**

```
E-Commerce: "Show order with customer and product details"

SQL (Normalized — 4 tables, JOINed at query time):
┌─────────┐     ┌──────────┐     ┌─────────────┐     ┌──────────┐
│  users  │     │  orders  │     │ order_items │     │ products │
├─────────┤     ├──────────┤     ├─────────────┤     ├──────────┤
│ id      │◄────│ user_id  │     │ order_id    │────▶│ id       │
│ name    │     │ id       │◄────│ product_id  │     │ name     │
│ email   │     │ total    │     │ quantity    │     │ price    │
└─────────┘     │ status   │     │ unit_price  │     └──────────┘
                └──────────┘     └─────────────┘

Query: SELECT u.name, o.total, p.name, oi.quantity
       FROM orders o
       JOIN users u ON o.user_id = u.id
       JOIN order_items oi ON oi.order_id = o.id
       JOIN products p ON oi.product_id = p.id
       WHERE o.id = 5001;

Pros: No data duplication, easy updates, flexible queries
Cons: 4-table JOIN on every read, slower at scale


NoSQL / MongoDB (Denormalized — 1 document, embedded):
{
  "_id": "order:5001",
  "customer": { "name": "Alice", "email": "alice@co.com" },
  "items": [
    { "product": "MacBook Pro", "price": 2499.99, "qty": 1 },
    { "product": "USB-C Cable", "price": 12.99, "qty": 2 }
  ],
  "total": 2525.97,
  "status": "shipped"
}

Query: db.orders.findOne({ _id: "order:5001" })

Pros: Single read, no JOINs, fast
Cons: Data duplication (product name/price copied),
      update Alice's email → must update ALL her orders
```

### When to Choose SQL

#### ✓ Financial Applications

Banking, payments, and any system where money is involved. Incorrect balances or double-charges are unacceptable.

```sql
-- Banking: Transfer with overdraft protection
BEGIN;
  -- Lock source account to prevent concurrent withdrawals
  SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;
  
  -- Verify sufficient funds
  -- (CHECK constraint also prevents negative balance)
  UPDATE accounts SET balance = balance - 500.00 WHERE id = 1;
  UPDATE accounts SET balance = balance + 500.00 WHERE id = 2;
  
  -- Audit trail
  INSERT INTO transactions (from_id, to_id, amount, type, created_at)
  VALUES (1, 2, 500.00, 'transfer', NOW());
COMMIT;
-- If ANY step fails → entire transfer rolls back
-- Customer never loses money
```

#### ✓ ERP / CRM Systems

Complex entity relationships, multi-table reports, and structured workflows.

```sql
-- CRM: Sales pipeline report across multiple related entities
SELECT 
    s.name as sales_rep,
    c.company_name,
    d.name as deal_name,
    d.stage,
    d.value,
    COUNT(a.id) as activities_this_month,
    MAX(a.created_at) as last_activity
FROM deals d
JOIN contacts c ON d.contact_id = c.id
JOIN sales_reps s ON d.assigned_to = s.id
LEFT JOIN activities a ON a.deal_id = d.id 
    AND a.created_at >= DATE_TRUNC('month', NOW())
WHERE d.stage IN ('negotiation', 'proposal')
    AND d.value > 10000
GROUP BY s.name, c.company_name, d.name, d.stage, d.value
HAVING COUNT(a.id) < 3  -- Flag deals with low activity
ORDER BY d.value DESC;
```

#### ✓ E-commerce — Inventory & Orders

Cannot oversell, must maintain accurate stock counts, need transactional order processing.

```sql
-- Place order with atomic inventory check + decrement
BEGIN;
  -- Lock the product row to prevent race conditions
  SELECT stock FROM products WHERE id = 101 FOR UPDATE;
  
  -- Decrement stock (CHECK constraint prevents going below 0)
  UPDATE products SET stock = stock - 2 WHERE id = 101 AND stock >= 2;
  
  -- If no rows updated → insufficient stock
  -- Application checks: IF affected_rows = 0 THEN ROLLBACK
  
  INSERT INTO orders (user_id, total, status) 
  VALUES (42, 59.98, 'confirmed') RETURNING id;
  
  INSERT INTO order_items (order_id, product_id, quantity, unit_price) 
  VALUES (currval('orders_id_seq'), 101, 2, 29.99);
COMMIT;

-- Without ACID: Two users buying the last 2 items simultaneously
-- could both succeed → oversold by 2 units!
```

#### ✓ Booking / Reservation Systems

Seats, hotel rooms, appointments — must prevent double-booking.

```sql
-- Hotel booking: Prevent double-booking with UNIQUE constraint + transaction
CREATE TABLE room_bookings (
    id          SERIAL PRIMARY KEY,
    room_id     INT NOT NULL REFERENCES rooms(id),
    check_in    DATE NOT NULL,
    check_out   DATE NOT NULL,
    guest_id    INT NOT NULL REFERENCES guests(id),
    CHECK (check_out > check_in),
    -- Exclusion constraint: no overlapping bookings for same room
    EXCLUDE USING gist (
        room_id WITH =,
        daterange(check_in, check_out) WITH &&
    )
);

-- This INSERT will fail if room 5 is already booked for those dates:
INSERT INTO room_bookings (room_id, check_in, check_out, guest_id)
VALUES (5, '2026-06-15', '2026-06-18', 42);
-- ERROR: conflicting key value violates exclusion constraint
-- The DATABASE prevents double-booking, not the application!
```

#### ✓ Analytics / Reporting

SQL excels at ad-hoc analytical queries that slice data in any dimension.

```sql
-- Complex business intelligence query:
-- Monthly cohort retention analysis
WITH cohorts AS (
    SELECT 
        user_id,
        DATE_TRUNC('month', MIN(created_at)) as cohort_month
    FROM orders
    GROUP BY user_id
),
monthly_activity AS (
    SELECT 
        c.cohort_month,
        DATE_TRUNC('month', o.created_at) as activity_month,
        COUNT(DISTINCT o.user_id) as active_users
    FROM orders o
    JOIN cohorts c ON o.user_id = c.user_id
    GROUP BY c.cohort_month, DATE_TRUNC('month', o.created_at)
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(*) as cohort_size
    FROM cohorts GROUP BY cohort_month
)
SELECT 
    TO_CHAR(ma.cohort_month, 'YYYY-MM') as cohort,
    cs.cohort_size,
    EXTRACT(MONTH FROM AGE(ma.activity_month, ma.cohort_month)) as months_since,
    ma.active_users,
    ROUND(ma.active_users * 100.0 / cs.cohort_size, 1) as retention_pct
FROM monthly_activity ma
JOIN cohort_sizes cs ON ma.cohort_month = cs.cohort_month
ORDER BY ma.cohort_month, months_since;

-- Result:
-- cohort  │ cohort_size │ months_since │ active_users │ retention_pct
-- ────────┼─────────────┼──────────────┼──────────────┼──────────────
-- 2026-01 │ 500         │ 0            │ 500          │ 100.0%
-- 2026-01 │ 500         │ 1            │ 215          │ 43.0%
-- 2026-01 │ 500         │ 2            │ 162          │ 32.4%
-- 2026-01 │ 500         │ 3            │ 138          │ 27.6%
-- 2026-02 │ 620         │ 0            │ 620          │ 100.0%
-- 2026-02 │ 620         │ 1            │ 285          │ 46.0%
```

### SQL Database Architecture: How It All Fits Together

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Client Applications                              │
│              (Web servers, APIs, microservices, scripts)                │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │ SQL queries via TCP/IP
                               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                     Connection Layer                                     │
│  ┌─────────────┐                                                        │
│  │ Connection   │  PgBouncer / ProxySQL (connection pooling)             │
│  │ Pool         │  → 10,000 app connections → 100 DB connections         │
│  └──────┬──────┘                                                        │
│         ▼                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                    │
│  │ Parser      │→ │ Planner/    │→ │ Executor    │                    │
│  │(SQL → AST)  │  │ Optimizer   │  │             │                    │
│  └─────────────┘  │             │  │ Seq Scan    │                    │
│                   │ Cost-based  │  │ Index Scan  │                    │
│                   │ optimizer   │  │ Hash Join   │                    │
│                   │ picks best  │  │ Merge Join  │                    │
│                   │ plan        │  │ Nested Loop │                    │
│                   └─────────────┘  └──────┬──────┘                    │
│                                           │                            │
├───────────────────────────────────────────┼────────────────────────────┤
│                     Storage Engine        │                            │
│                                           ▼                            │
│  ┌─────────────────────────────────────────────────────────────┐       │
│  │                    Buffer Pool (Shared Memory)              │       │
│  │  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐       │       │
│  │  │ Page  │ │ Page  │ │ Page  │ │ Page  │ │ Page  │ ...   │       │
│  │  │  1    │ │  2    │ │  3    │ │  4    │ │  5    │       │       │
│  │  └───────┘ └───────┘ └───────┘ └───────┘ └───────┘       │       │
│  │  Hot data cached in RAM → avoids disk reads               │       │
│  │  Typical hit rate: 95-99% for OLTP workloads              │       │
│  └─────────────────────────────────────────────────────────────┘       │
│                    │                    │                              │
│         ┌──────────┘                    └──────────┐                  │
│         ▼                                          ▼                  │
│  ┌─────────────┐                          ┌─────────────┐            │
│  │    WAL      │                          │  Data Files │            │
│  │ (Write      │                          │  (Tables,   │            │
│  │  Ahead Log) │                          │   Indexes)  │            │
│  │             │                          │             │            │
│  │ Sequential  │                          │ Random I/O  │            │
│  │ writes only │                          │ 8KB pages   │            │
│  │ (fast!)     │                          │             │            │
│  └─────────────┘                          └─────────────┘            │
│         │                                                            │
│         ▼                                                            │
│  ┌─────────────┐                                                     │
│  │  Replicas   │  WAL streaming → standby servers                    │
│  │ (read-only) │  Async or sync replication                          │
│  └─────────────┘                                                     │
└──────────────────────────────────────────────────────────────────────┘

EXPLAIN ANALYZE shows this pipeline in action:

EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = 42;

-- Index Scan using idx_orders_user_id on orders
--   Index Cond: (user_id = 42)
--   Rows Removed by Filter: 0
--   Planning Time: 0.150 ms
--   Execution Time: 0.045 ms       ← 45 microseconds!
--   Buffers: shared hit=3           ← 3 pages from buffer pool (no disk)
```

### Alternatives to Traditional SQL

#### 1. NewSQL (Distributed SQL)

NewSQL databases provide SQL semantics with ACID transactions **across distributed nodes**. They solve the biggest SQL limitation — horizontal scaling — while keeping the familiar SQL interface.

**Databases:** CockroachDB, Google Spanner, YugabyteDB, TiDB

```
Traditional SQL:                        NewSQL (CockroachDB/Spanner):

  ┌──────────────┐                      ┌──────────┐ ┌──────────┐ ┌──────────┐
  │              │                      │  Node 1  │ │  Node 2  │ │  Node 3  │
  │  Single      │                      │  US-East │ │  EU-West │ │  AP-SE   │
  │  Server      │                      │          │ │          │ │          │
  │              │                      │  Range   │ │  Range   │ │  Range   │
  │  Scale: ↕    │                      │  [A-G]   │ │  [H-P]   │ │  [Q-Z]   │
  │  (vertical)  │                      └────┬─────┘ └────┬─────┘ └────┬─────┘
  └──────────────┘                           │            │            │
                                             └──── Raft Consensus ────┘
  ✗ Single region                              (distributed transactions)
  ✗ Max ~10TB                           
  ✗ Single point of failure             ✓ Multi-region
                                        ✓ Petabyte scale
                                        ✓ Auto-failover
                                        ✓ Full ACID across nodes
```

**CockroachDB example:**

```sql
-- Create a geo-partitioned table (data stays near users)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name STRING NOT NULL,
    email STRING NOT NULL UNIQUE,
    region STRING NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW;

-- This is standard SQL — works just like PostgreSQL
INSERT INTO users (name, email, region) 
VALUES ('Alice', 'alice@co.com', 'us-east-1');

SELECT * FROM users WHERE email = 'alice@co.com';

-- Distributed transaction across regions — just works!
BEGIN;
  UPDATE accounts SET balance = balance - 100 WHERE id = 'alice-us';
  UPDATE accounts SET balance = balance + 100 WHERE id = 'bob-eu';
COMMIT;
-- Uses Raft consensus + 2PC under the hood
-- Higher latency (~50-100ms for cross-region) but fully ACID
```

```
When to use NewSQL vs Traditional SQL:

Traditional SQL (PostgreSQL):           NewSQL (CockroachDB):
─ Data < 10TB                           ─ Data > 10TB
─ Single region                         ─ Multi-region required
─ Can tolerate failover time            ─ Zero-downtime required
─ Cost-sensitive                        ─ Can afford higher latency
─ Simple operations                     ─ Need auto-scaling
─ Latency-critical (<5ms)              ─ Latency-tolerant (~20-100ms)
```

---

#### 2. Time-Series Databases

Purpose-built for timestamp-indexed data with extremely high write throughput, built-in downsampling, and time-range query optimizations.

**Databases:** InfluxDB, TimescaleDB, Prometheus, QuestDB

```
Why not just use PostgreSQL for time-series?

PostgreSQL (1M sensor readings/day):
  ├─ Storage: 50GB/month (row-oriented, no compression)
  ├─ Insert speed: ~10K/sec
  ├─ Query "avg temp last hour": ~500ms (sequential scan)
  └─ Retention: Manual DELETE + VACUUM

TimescaleDB (PostgreSQL extension, same data):
  ├─ Storage: 5GB/month (columnar compression, 10x smaller)
  ├─ Insert speed: ~100K/sec (hypertable auto-partitioning)
  ├─ Query "avg temp last hour": ~5ms (chunk exclusion)
  └─ Retention: Automatic drop_chunks policy
```

**TimescaleDB example (PostgreSQL extension — keeps SQL compatibility):**

```sql
-- Create a hypertable (auto-partitioned by time)
CREATE TABLE sensor_data (
    time        TIMESTAMPTZ NOT NULL,
    sensor_id   TEXT NOT NULL,
    temperature DOUBLE PRECISION,
    humidity    DOUBLE PRECISION,
    battery_pct INT
);

-- Convert to hypertable (chunks by 1 day)
SELECT create_hypertable('sensor_data', 'time', chunk_time_interval => INTERVAL '1 day');

-- Insert data (same as regular PostgreSQL)
INSERT INTO sensor_data VALUES 
    (NOW(), 'sensor-001', 23.5, 65.0, 87),
    (NOW(), 'sensor-002', 19.3, 72.0, 91);

-- Time-bucketed aggregation (built-in function)
SELECT 
    time_bucket('5 minutes', time) as bucket,
    sensor_id,
    AVG(temperature) as avg_temp,
    MAX(temperature) as max_temp,
    MIN(temperature) as min_temp
FROM sensor_data
WHERE time > NOW() - INTERVAL '1 hour'
GROUP BY bucket, sensor_id
ORDER BY bucket DESC;

-- Continuous aggregates (pre-computed materialized views)
CREATE MATERIALIZED VIEW sensor_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', time) as hour,
    sensor_id,
    AVG(temperature) as avg_temp,
    COUNT(*) as reading_count
FROM sensor_data
GROUP BY hour, sensor_id;

-- Automatic retention: drop data older than 90 days
SELECT add_retention_policy('sensor_data', INTERVAL '90 days');

-- Automatic compression: compress chunks older than 7 days
ALTER TABLE sensor_data SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sensor_id'
);
SELECT add_compression_policy('sensor_data', INTERVAL '7 days');
```

---

#### 3. NoSQL (Document, Key-Value, Graph, Wide-Column)

Non-relational databases optimized for specific data models and access patterns.

```
Type              Best For                    Example            Key Trade-off
───────────────   ─────────────────────────   ────────────────   ────────────────────
Key-Value         Caching, sessions           Redis, DynamoDB    No queries on values
Document          Flexible schemas, CMS       MongoDB, CouchDB   Weak JOINs
Wide-Column       Time-series, IoT            Cassandra, HBase   Must design tables per query
Graph             Social networks, fraud      Neo4j, Neptune     Hard to scale horizontally
```

**When NoSQL is clearly better than SQL:**

```sql
-- SQL: "Get user session" requires a table scan or index lookup
-- through the full RDBMS stack (parser → planner → executor → disk)
SELECT data FROM sessions WHERE token = 'abc123';
-- ~5ms with index

-- Redis: Direct key-value lookup, in-memory
-- GET session:abc123
-- ~0.1ms (50x faster)

-- SQL: Flexible product attributes (see EAV problem above)
-- MongoDB: Just store whatever fields you need per document
-- { category: "laptop", cpu: "M3", ram: "36GB", ... }

-- SQL: "Find friends of friends of friends" (3 self-JOINs)
-- ~30 seconds on 1M users
-- Neo4j: MATCH (u)-[:FRIENDS*3]->(fof) RETURN fof
-- ~2 milliseconds (15,000x faster)
```

---

#### 4. Multi-Model Databases

Single database that supports multiple data models — documents, graphs, key-value — with one query language.

**Databases:** ArangoDB, OrientDB, SurrealDB, FaunaDB

```
Traditional Polyglot Architecture:      Multi-Model Architecture:

┌──────────┐                            ┌──────────────────────────┐
│PostgreSQL│ (relational)               │                          │
├──────────┤                            │      ArangoDB            │
│ MongoDB  │ (documents)                │                          │
├──────────┤                            │  Documents ✓             │
│  Redis   │ (key-value)                │  Graphs    ✓             │
├──────────┤                            │  Key-Value ✓             │
│  Neo4j   │ (graph)                    │  Search    ✓             │
└──────────┘                            │                          │
                                        │  One query language (AQL)│
4 databases to manage                   │  One backup strategy     │
4 query languages                       │  One operations team     │
4 backup strategies                     └──────────────────────────┘
Complex data sync between them          
                                        Trade-off: "Jack of all trades,
                                        master of none" — each model
                                        is good but not best-in-class
```

**SurrealDB example (SQL-like syntax for multi-model):**

```sql
-- Define a schema with relations (document + graph in one)
DEFINE TABLE user SCHEMAFULL;
DEFINE FIELD name ON user TYPE string;
DEFINE FIELD email ON user TYPE string;

-- Create records (document-style)
CREATE user:alice SET name = 'Alice', email = 'alice@co.com';
CREATE user:bob SET name = 'Bob', email = 'bob@co.com';

-- Create graph relationships (graph-style)
RELATE user:alice->friends->user:bob SET since = '2024-01-15';
RELATE user:alice->purchased->product:macbook SET date = '2026-05-01';

-- Query combining document + graph traversal
SELECT 
    name,
    ->friends->user.name AS friend_names,
    ->purchased->product.name AS purchased_products
FROM user:alice;
```

---

#### 5. Data Warehouses & OLAP Databases

Optimized for **analytical queries** (OLAP) on very large datasets. Column-oriented storage for fast aggregations.

**Databases:** ClickHouse, Apache Druid, Google BigQuery, Snowflake, Amazon Redshift

```
OLTP (PostgreSQL)                       OLAP (ClickHouse)
─────────────────                       ──────────────────
Row-oriented storage                    Column-oriented storage
┌─────┬──────┬───────┐                 ┌───────────────────────┐
│ id  │ name │ sales │                 │ id:    [1, 2, 3, 4]  │
├─────┼──────┼───────┤                 │ name:  [A, B, C, D]  │
│  1  │  A   │  100  │                 │ sales: [100,200,     │
│  2  │  B   │  200  │                 │         150,300]     │
│  3  │  C   │  150  │                 └───────────────────────┘
│  4  │  D   │  300  │                 
└─────┴──────┴───────┘                 SUM(sales): reads only the
                                       sales column → 4 values
SUM(sales): must read all              vs reading all rows
rows and skip id, name columns         
                                       10-100x faster for aggregations
Optimized for: single-row              Optimized for: many-row
reads/writes (transactions)            analytical queries
```

```sql
-- ClickHouse: Analyze 1 billion page views in seconds
SELECT 
    toDate(timestamp) as day,
    countIf(event = 'purchase') as purchases,
    countIf(event = 'page_view') as views,
    round(purchases / views * 100, 2) as conversion_rate
FROM events
WHERE timestamp >= '2026-01-01'
GROUP BY day
ORDER BY day;

-- 1 billion rows → ~2 seconds (vs minutes in PostgreSQL)
-- ClickHouse processes ~1-2 billion rows/sec per core
```

### Decision Flowchart: Choosing the Right Database

```
                           START
                             │
                ┌────────────▼─────────────┐
                │  What type of workload?  │
                └────┬──────────────┬──────┘
                     │              │
              Transactional     Analytical
              (OLTP)            (OLAP)
                     │              │
                     │         ┌────▼───────────────┐
                     │         │ Data warehouse:     │
                     │         │ ClickHouse, BigQuery│
                     │         │ Snowflake, Redshift │
                     │         └────────────────────┘
                     │
        ┌────────────▼─────────────┐
        │  Need ACID transactions  │
        │  across multiple tables? │
        └────┬──────────────┬──────┘
             │              │
            YES             NO
             │              │
    ┌────────▼────────┐    ┌▼─────────────────────┐
    │ Need horizontal │    │ What's the primary   │
    │ scaling (>10TB)?│    │ data access pattern?  │
    └───┬────────┬────┘    └──┬───┬───┬───┬───┬───┘
        │        │            │   │   │   │   │
       YES      NO            │   │   │   │   │
        │        │          Key Documents Graph Time  Search
        │        │          Val           Series
   ┌────▼─────┐ ┌▼─────┐   │   │   │     │     │
   │ NewSQL:  │ │ SQL:  │   ▼   ▼   ▼     ▼     ▼
   │CockroachDB│PostgreSQL Redis MongoDB Neo4j InfluxDB Elastic
   │Spanner   │ │MySQL  │  DynamoDB CouchDB     TimescaleDB search
   │YugabyteDB│ │       │                       Prometheus
   └──────────┘ └───────┘
```
