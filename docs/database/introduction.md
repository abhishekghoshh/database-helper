# Database Introduction


## Youtube


### Introduction

- [How do Databases Work? | System Design](https://www.youtube.com/watch?v=FnsIJAaGRk4)
- [The fascinating history of Databases](https://www.youtube.com/watch?v=6szdySvorzA)
- [15 futuristic databases you've never heard of](https://www.youtube.com/watch?v=jb2AvF8XzII)


### Playlists

- [Database Engineering](https://www.youtube.com/playlist?list=PLsdq-3Z1EPT2C-Da7Jscr7NptGcIZgQ2l)
- [Database](https://www.youtube.com/playlist?list=PLCRMIe5FDPsdnSszazqVIQFh99t1ExH19)
- [Database Design](https://www.youtube.com/playlist?list=PLZDOU071E4v6epq3GS0IqZicZc3xwwBN_)
- [Complete DBMS Course](https://www.youtube.com/playlist?list=PLrL_PSQ6q062cD0vPMGYW_AIpNg6T0_Fq)
- [Databases in Depth](https://www.youtube.com/playlist?list=PLliXPok7ZonnALnedG5doBOSCXlU14yJF)
- [Database Programming from scratch](https://www.youtube.com/playlist?list=PLdYoxziVZt9DWfdxTnXDYdc3F2TFT9jzV)
- [DBMS Placements Series](https://www.youtube.com/playlist?list=PLDzeHZWIZsTpukecmA2p5rhHM14bl2dHU)
- [Database Tutorials](https://www.youtube.com/playlist?list=PLiMWaCMwGJXnhmmh5pu9sdWekdRwAzV5f)
- [Database in kubernetes](https://www.youtube.com/playlist?list=PLyicRj904Z9_58pmbrkCrQqgvijy8JnP2)
- [Database Engineering](https://www.youtube.com/playlist?list=PLQnljOFTspQXjD0HOzN7P2tgzu7scWpl2)
- [Relational database (RDBMS) by Decomplexify](https://www.youtube.com/playlist?list=PLNITTkCQVxeXryTQvY0JBWTyN9ynxxPH8)


### DBMS(IIT)

- [Data Base Management System | IIT-KGP](https://www.youtube.com/playlist?list=PLIwC9bZ0rmjSkm1VRJROX4vP2YMIf4Ebh)
- [Database Management Systems | IIT-MADRAS](https://www.youtube.com/playlist?list=PLZ2ps__7DhBYc4jkUk_yQAjYEVFzVzhdU)



## Udemy

### Introduction

- [Cloud Computing for Beginners - Database Technologies](https://www.udemy.com/course/cloud-computing-for-beginners-database-technologies/)
- [Relational Database Design](https://www.udemy.com/course/relational-database-design/)


### DBMS

- [Fundamentals of Database Engineering](https://www.udemy.com/course/database-engines-crash-course/)
- [Database Management System from scratch in parts]()
    - [Database Management System from scratch - Part 1](https://www.udemy.com/course/database-management-systems/)
    - [Database Management System from scratch - Part 2](https://www.udemy.com/course/database-management-system-course/)
    - [Database Management Systems Part 3 : SQL Interview Course](https://www.udemy.com/course/sql-interview-preparation-course/)
    - [Database Management Systems Part 4 : Transactions](https://www.udemy.com/course/database-management-systems-transactions/)
    - [Database Management Final Part (5): Indexing,B Trees,B+Trees](https://www.udemy.com/course/database-management-indexing-course-btree/)
- [Complete SQL and Databases Bootcamp](https://www.udemy.com/course/complete-sql-databases-bootcamp-zero-to-mastery/)



## Theory

### What is a Database?

A **database** is an organized collection of structured data stored electronically. A **Database Management System (DBMS)** is the software that manages, stores, retrieves, and secures that data.

```
Application Stack:
┌─────────────────────────────────┐
│        Application Code         │
│  (Java, Python, Node.js, etc.) │
└──────────────┬──────────────────┘
               │  SQL / API calls
               ↓
┌─────────────────────────────────┐
│   Database Management System    │
│          (DBMS)                 │
│  ┌───────────────────────────┐  │
│  │     Query Processor       │  │  ← Parses, optimizes, executes queries
│  ├───────────────────────────┤  │
│  │   Transaction Manager     │  │  ← ACID guarantees
│  ├───────────────────────────┤  │
│  │     Buffer Manager        │  │  ← Page cache in memory
│  ├───────────────────────────┤  │
│  │     Storage Engine        │  │  ← Reads/writes data on disk
│  ├───────────────────────────┤  │
│  │   Lock Manager / MVCC     │  │  ← Concurrency control
│  └───────────────────────────┘  │
└──────────────┬──────────────────┘
               │
               ↓
┌─────────────────────────────────┐
│      Disk / SSD Storage         │
│  Data files, Index files, WAL   │
└─────────────────────────────────┘
```

---

### Types of Databases

```
┌───────────────────────────────────────────────────────────────────────┐
│                     DATABASE LANDSCAPE                                │
├───────────────────┬───────────────────────────────────────────────────┤
│                   │                                                   │
│   RELATIONAL      │   NON-RELATIONAL (NoSQL)                         │
│   (SQL)           │                                                   │
│                   │   ┌──────────────┐  ┌─────────────────┐          │
│   ┌────────────┐  │   │  Document    │  │  Key-Value      │          │
│   │ PostgreSQL │  │   │  MongoDB     │  │  Redis          │          │
│   │ MySQL      │  │   │  CouchDB     │  │  DynamoDB       │          │
│   │ SQL Server │  │   └──────────────┘  │  Memcached      │          │
│   │ Oracle     │  │                     └─────────────────┘          │
│   │ SQLite     │  │   ┌──────────────┐  ┌─────────────────┐          │
│   └────────────┘  │   │  Column      │  │  Graph          │          │
│                   │   │  Cassandra   │  │  Neo4j          │          │
│   Tables, rows,   │   │  HBase       │  │  ArangoDB       │          │
│   schemas, SQL,   │   │  ClickHouse  │  │  Amazon Neptune │          │
│   JOINs, ACID     │   └──────────────┘  └─────────────────┘          │
│                   │                                                   │
│                   │   ┌──────────────┐  ┌─────────────────┐          │
│                   │   │  Time-Series │  │  Vector          │          │
│                   │   │  InfluxDB    │  │  Pinecone        │          │
│                   │   │  TimescaleDB │  │  Milvus          │          │
│                   │   │  Prometheus  │  │  Weaviate        │          │
│                   │   └──────────────┘  └─────────────────┘          │
│                   │                                                   │
│   NEW SQL         │   ┌──────────────┐                               │
│   ┌────────────┐  │   │  Search      │                               │
│   │CockroachDB │  │   │  Elasticsearch│                              │
│   │YugabyteDB  │  │   │  Solr        │                               │
│   │TiDB        │  │   └──────────────┘                               │
│   └────────────┘  │                                                   │
│   SQL + horizontal│                                                   │
│   scaling         │                                                   │
└───────────────────┴───────────────────────────────────────────────────┘
```

| Type | Data Model | Best For | Examples |
|------|-----------|----------|---------|
| **Relational** | Tables, rows, columns | Structured data, ACID transactions | PostgreSQL, MySQL |
| **Document** | JSON/BSON documents | Flexible schemas, content management | MongoDB, CouchDB |
| **Key-Value** | Key → Value pairs | Caching, sessions, simple lookups | Redis, DynamoDB |
| **Column-Family** | Column families, wide rows | Analytics, time-series at scale | Cassandra, HBase |
| **Graph** | Nodes + edges | Relationships, social networks | Neo4j, ArangoDB |
| **Time-Series** | Timestamped data points | Metrics, IoT, monitoring | InfluxDB, TimescaleDB |
| **Vector** | High-dimensional vectors | AI/ML similarity search, RAG | Pinecone, Milvus |
| **Search** | Inverted indexes | Full-text search, log analysis | Elasticsearch |
| **NewSQL** | Tables (distributed) | SQL at horizontal scale | CockroachDB, TiDB |

For detailed SQL vs NoSQL comparison, see [Comparisons](comparisions.md). For NoSQL deep-dive, see [NoSQL](nosql.md).

---

### Transactions and ACID Overview

A **transaction** is a logical unit of work that consists of one or more database operations (reads/writes) that must be treated as a single, indivisible operation. Either all operations succeed, or none of them take effect.

**Why Transactions Matter:**
```
Bank Transfer: Move $100 from Account A to Account B

Step 1: Debit Account A by $100
Step 2: Credit Account B by $100

What if the system crashes after Step 1 but before Step 2?
  → Without transactions: $100 disappears (money lost!)
  → With transactions: Both steps roll back (money safe)
```

**Transaction Lifecycle:**

```
┌─────────┐    BEGIN     ┌────────────┐   Operations   ┌────────────┐
│  Idle   │────────────→│   Active    │──────────────→│   Active   │
└─────────┘             └────────────┘   (READ/WRITE)  └─────┬──────┘
                                                              │
                                                    ┌─────────┴─────────┐
                                                    ↓                   ↓
                                              ┌──────────┐       ┌──────────┐
                                              │ COMMIT   │       │ ROLLBACK │
                                              │ (success)│       │ (failure)│
                                              └─────┬────┘       └─────┬────┘
                                                    ↓                   ↓
                                              ┌──────────┐       ┌──────────┐
                                              │Committed │       │ Aborted  │
                                              │(durable) │       │(undone)  │
                                              └──────────┘       └──────────┘
```

**PostgreSQL Transaction Example:**

```sql
BEGIN;

-- Step 1: Debit Account A
UPDATE accounts SET balance = balance - 100 WHERE id = 'A';

-- Step 2: Credit Account B
UPDATE accounts SET balance = balance + 100 WHERE id = 'B';

-- Verify constraint: no negative balance
-- (If Account A has insufficient funds, the CHECK constraint fails
--  and the entire transaction is rolled back)

COMMIT;
-- Both updates are now permanently applied
```

**MySQL Transaction Example:**

```sql
START TRANSACTION;

UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
UPDATE accounts SET balance = balance + 100 WHERE id = 'B';

-- Check if something went wrong
-- If error → ROLLBACK; else → COMMIT;
COMMIT;
```

**Application-Level Transaction (Python + psycopg2):**

```python
import psycopg2

conn = psycopg2.connect("dbname=bank user=admin")
try:
    with conn.cursor() as cur:
        cur.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 'A'")
        cur.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 'B'")

        # Verify no negative balance
        cur.execute("SELECT balance FROM accounts WHERE id = 'A'")
        balance = cur.fetchone()[0]
        if balance < 0:
            conn.rollback()
            raise ValueError("Insufficient funds")

    conn.commit()  # Both updates applied atomically
except Exception as e:
    conn.rollback()  # Undo everything
    raise
finally:
    conn.close()
```

**Java (JDBC):**

```java
Connection conn = DriverManager.getConnection(url, user, password);
conn.setAutoCommit(false);  // Start transaction

try {
    PreparedStatement debit = conn.prepareStatement(
        "UPDATE accounts SET balance = balance - ? WHERE id = ?");
    debit.setBigDecimal(1, new BigDecimal("100"));
    debit.setString(2, "A");
    debit.executeUpdate();

    PreparedStatement credit = conn.prepareStatement(
        "UPDATE accounts SET balance = balance + ? WHERE id = ?");
    credit.setBigDecimal(1, new BigDecimal("100"));
    credit.setString(2, "B");
    credit.executeUpdate();

    conn.commit();  // Atomic commit
} catch (SQLException e) {
    conn.rollback();  // Undo everything
    throw e;
} finally {
    conn.setAutoCommit(true);
    conn.close();
}
```

**Savepoints — Partial Rollback:**

```sql
BEGIN;

INSERT INTO orders (id, customer_id, total) VALUES (1, 100, 500.00);

SAVEPOINT before_items;

INSERT INTO order_items (order_id, product_id, qty) VALUES (1, 10, 2);
INSERT INTO order_items (order_id, product_id, qty) VALUES (1, 99, 1);
-- Product 99 doesn't exist → error!

ROLLBACK TO SAVEPOINT before_items;
-- Only order_items are undone, the order INSERT is preserved

INSERT INTO order_items (order_id, product_id, qty) VALUES (1, 10, 2);
INSERT INTO order_items (order_id, product_id, qty) VALUES (1, 20, 1);

COMMIT;
-- Order + valid items committed
```

---

### ACID Properties — The Four Guarantees

#### Atomicity — All or Nothing

A transaction is treated as a single unit. If any part fails, the entire transaction is rolled back. The database uses an **undo log** to reverse partial changes.

```
Transaction: Transfer $100 from A to B

  ┌──────────────────────────────────────────────────┐
  │ BEGIN TRANSACTION                                │
  │                                                  │
  │   UPDATE A: balance = 1000 → 900    ✅          │
  │   (Undo log: A was 1000)                        │
  │                                                  │
  │   UPDATE B: balance = 500 → 600     ✅          │
  │   (Undo log: B was 500)                         │
  │                                                  │
  │ COMMIT ✅                                        │
  │ → Undo log discarded, changes permanent         │
  └──────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────┐
  │ BEGIN TRANSACTION                                │
  │                                                  │
  │   UPDATE A: balance = 1000 → 900    ✅          │
  │   (Undo log: A was 1000)                        │
  │                                                  │
  │   UPDATE B: ERROR! (constraint violation) ❌    │
  │                                                  │
  │ ROLLBACK                                         │
  │ → Use undo log: restore A to 1000              │
  │ → Database unchanged                            │
  └──────────────────────────────────────────────────┘
```

**How Atomicity is Implemented:**

| Database | Mechanism | Details |
|----------|-----------|---------|
| **PostgreSQL** | MVCC (Multi-Version) | Old row versions kept until no transaction needs them |
| **MySQL InnoDB** | Undo Log | Writes undo records to undo tablespace before modifying |
| **SQL Server** | Transaction Log | Write-ahead log records before/after images |
| **Oracle** | Undo Segments | Undo tablespace stores before-images |

---

#### Consistency — Valid State to Valid State

A transaction takes the database from one valid state to another. All constraints must be satisfied after the transaction completes.

```
BEFORE transaction:
  Account A: $1000   Account B: $500
  Total: $1500 ✅ (invariant: total money in system)

DURING transaction:
  Account A: $900    Account B: $500
  Total: $1400 ❌ (temporarily inconsistent — that's OK, transaction is in progress)

AFTER transaction:
  Account A: $900    Account B: $600
  Total: $1500 ✅ (invariant preserved)
```

**Types of Constraints That Enforce Consistency:**

```sql
CREATE TABLE accounts (
    id          VARCHAR(10) PRIMARY KEY,          -- Entity integrity
    owner_name  VARCHAR(100) NOT NULL,             -- NOT NULL constraint
    balance     DECIMAL(12,2) CHECK (balance >= 0),-- CHECK constraint (no negative balance)
    account_type VARCHAR(20) DEFAULT 'checking',
    branch_id   INT REFERENCES branches(id),      -- Foreign key (referential integrity)
    email       VARCHAR(255) UNIQUE                -- Unique constraint
);

-- Custom constraint via trigger
CREATE OR REPLACE FUNCTION check_total_balance()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT SUM(balance) FROM accounts) < 0 THEN
        RAISE EXCEPTION 'Total system balance cannot be negative';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_total_balance
AFTER INSERT OR UPDATE ON accounts
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_total_balance();
```

---

#### Isolation — Concurrent Transactions Don't Interfere

Multiple transactions running simultaneously behave as if they run sequentially. Without isolation, several anomalies can occur:

**Concurrency Problems:**

```
DIRTY READ (reading uncommitted data):
  T1: UPDATE accounts SET balance = 900 WHERE id = 'A';  (not committed yet)
  T2: SELECT balance FROM accounts WHERE id = 'A';  → reads 900
  T1: ROLLBACK;  → balance goes back to 1000
  T2: Used the value 900 which NEVER actually existed! ❌

NON-REPEATABLE READ (same query, different results):
  T1: SELECT balance FROM accounts WHERE id = 'A';  → 1000
  T2: UPDATE accounts SET balance = 900 WHERE id = 'A'; COMMIT;
  T1: SELECT balance FROM accounts WHERE id = 'A';  → 900 (different!)
  T1: Same query, two different answers within one transaction ❌

PHANTOM READ (new rows appear):
  T1: SELECT COUNT(*) FROM orders WHERE status = 'pending';  → 5
  T2: INSERT INTO orders (status) VALUES ('pending'); COMMIT;
  T1: SELECT COUNT(*) FROM orders WHERE status = 'pending';  → 6
  T1: A new "phantom" row appeared within the same transaction ❌

LOST UPDATE (overwriting concurrent change):
  T1: Read balance = 1000
  T2: Read balance = 1000
  T1: Write balance = 1000 + 100 = 1100  (deposit $100)
  T2: Write balance = 1000 - 50 = 950    (withdraw $50)
  Final: balance = 950 (T1's deposit is LOST!) ❌
  Expected: 1050
```

**Isolation Levels — What Each Prevents:**

```
┌──────────────────┬─────────────┬──────────────────┬───────────────┬─────────────┐
│ Isolation Level  │ Dirty Read  │ Non-Repeatable   │ Phantom Read  │ Lost Update │
│                  │             │ Read             │               │             │
├──────────────────┼─────────────┼──────────────────┼───────────────┼─────────────┤
│ Read Uncommitted │ ❌ Possible │ ❌ Possible      │ ❌ Possible   │ ❌ Possible │
│ Read Committed   │ ✅ Prevented│ ❌ Possible      │ ❌ Possible   │ ❌ Possible │
│ Repeatable Read  │ ✅ Prevented│ ✅ Prevented     │ ❌ Possible*  │ ✅ Prevented│
│ Serializable     │ ✅ Prevented│ ✅ Prevented     │ ✅ Prevented  │ ✅ Prevented│
└──────────────────┴─────────────┴──────────────────┴───────────────┴─────────────┘
* MySQL InnoDB's Repeatable Read also prevents phantom reads via gap locks
```

**Setting Isolation Levels:**

```sql
-- PostgreSQL
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN;
-- ... operations ...
COMMIT;

-- Or per-session
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- MySQL
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
-- ... operations ...
COMMIT;

-- Check current level
-- PostgreSQL:
SHOW transaction_isolation;
-- MySQL:
SELECT @@transaction_isolation;
```

**Isolation Level Deep Dive — Read Committed vs Repeatable Read:**

```sql
-- Read Committed (PostgreSQL default):
-- Each statement sees the latest committed data

Session 1:                          Session 2:
BEGIN;
SELECT balance FROM accounts
WHERE id = 'A';  → 1000
                                    BEGIN;
                                    UPDATE accounts SET balance = 900
                                    WHERE id = 'A';
                                    COMMIT;
SELECT balance FROM accounts
WHERE id = 'A';  → 900 (changed!)
COMMIT;

-- Repeatable Read (MySQL InnoDB default):
-- Snapshot taken at start of transaction — reads are frozen

Session 1:                          Session 2:
BEGIN;
SELECT balance FROM accounts
WHERE id = 'A';  → 1000
                                    BEGIN;
                                    UPDATE accounts SET balance = 900
                                    WHERE id = 'A';
                                    COMMIT;
SELECT balance FROM accounts
WHERE id = 'A';  → 1000 (still!)
COMMIT;
-- Session 1 sees a consistent snapshot from BEGIN time
```

**Performance vs Safety Trade-off:**

```
Safety:      LOW ◄──────────────────────────────────► HIGH
             Read         Read         Repeatable     Serializable
             Uncommitted  Committed    Read

Performance: HIGH ◄──────────────────────────────────► LOW
             Read         Read         Repeatable     Serializable
             Uncommitted  Committed    Read

Typical defaults:
  PostgreSQL: Read Committed (balanced — good for most workloads)
  MySQL:      Repeatable Read (safer for read-heavy apps)
  Oracle:     Read Committed
  SQL Server: Read Committed
```

---

#### Durability — Committed Data Survives Crashes

Once a transaction is committed, the data persists even if the system crashes, power goes out, or hardware fails. This is achieved through **Write-Ahead Logging (WAL)**.

**Write-Ahead Log (WAL) — How Durability Works:**

```
Without WAL (dangerous):
  1. Application: COMMIT
  2. Database writes data directly to data files on disk
  3. 💥 CRASH during write!
  4. Data file is half-written → CORRUPTED ❌

With WAL (safe):
  1. Application: COMMIT
  2. Database writes change to WAL file (sequential, fast) → fsync to disk
  3. Returns "COMMIT OK" to application
  4. Later: Background process writes WAL changes to actual data files
  5. 💥 Even if crash happens before step 4:
     → On restart, replay WAL to reconstruct all committed changes ✅

┌─────────────┐    ┌──────────────────────────────────────────────┐
│ Transaction │    │              WRITE-AHEAD LOG                 │
│   COMMIT    │───→│  LSN 101: UPDATE accounts SET bal=900 (A)   │
│             │    │  LSN 102: UPDATE accounts SET bal=600 (B)   │
└─────────────┘    │  LSN 103: COMMIT                             │
                   └──────────────────────────────────────────────┘
                           │                    │
                   Written to disk         Background writer
                   BEFORE commit reply     applies to data files
                           │                    │
                           ↓                    ↓
                   ┌──────────────┐    ┌──────────────────┐
                   │  WAL on Disk │    │  Data Files      │
                   │  (sequential │    │  (random writes)  │
                   │   writes)    │    │  accounts.dat     │
                   └──────────────┘    └──────────────────┘
```

**Why WAL is Fast:**
- WAL writes are **sequential** (append-only) → SSDs/HDDs are fast at sequential writes
- Data file writes are **random** (update row at arbitrary position) → slow
- WAL batches multiple small writes into larger sequential writes

**PostgreSQL WAL Configuration:**

```ini
# postgresql.conf
wal_level = replica              # minimal, replica, or logical
fsync = on                       # Force WAL to disk on commit (NEVER turn off in production!)
synchronous_commit = on          # Wait for WAL flush before returning COMMIT
wal_buffers = 16MB               # Memory buffer for WAL before flushing
checkpoint_timeout = 5min        # How often to flush WAL to data files
max_wal_size = 1GB               # Max WAL before forced checkpoint
```

**Checkpoints — Flushing WAL to Data Files:**

```
WAL grows continuously:
  [LSN 1][LSN 2][LSN 3][LSN 4]...[LSN 1000][LSN 1001]...

Checkpoint at LSN 500:
  → All changes up to LSN 500 are flushed to data files
  → WAL before LSN 500 can be recycled
  → On crash recovery, only replay from LSN 500 onward

┌─────────────────────────────────────────────────────┐
│ WAL: [1][2][3]...[500][501]...[1000]                │
│                      ↑                              │
│               CHECKPOINT                             │
│         (data files up to date)                     │
│                                                     │
│ On crash at LSN 800:                                │
│   Replay LSN 501 → 800 from WAL                    │
│   (not from the beginning — fast recovery!)         │
└─────────────────────────────────────────────────────┘
```

---

### Concurrency Control

How databases allow multiple transactions to operate simultaneously without corrupting data.

#### Pessimistic Concurrency — Locking

Transactions acquire **locks** on data before accessing it. Other transactions must wait.

```
EXCLUSIVE LOCK (write lock):
  T1: LOCK row A (exclusive)
  T2: Want to READ row A → BLOCKED (waiting...)
  T1: UPDATE row A, COMMIT, RELEASE lock
  T2: Now can read row A

SHARED LOCK (read lock):
  T1: LOCK row A (shared — for reading)
  T2: LOCK row A (shared — for reading) ✅ (multiple readers OK)
  T3: Want to WRITE row A → BLOCKED (shared locks held)
  T1, T2: COMMIT, RELEASE locks
  T3: Now can write row A
```

**Lock Granularity:**

```
┌──────────────────────────────────────────────────────────────┐
│  COARSE ◄──────────────────────────────────────► FINE       │
│                                                              │
│  Table Lock    Page Lock    Row Lock    Column Lock          │
│                                                              │
│  ✅ Simple     ✅ Medium    ✅ High     ✅ Highest           │
│  ❌ Low        ❌ Medium    ❌ Some     ❌ High              │
│  concurrency   concurrency  overhead    overhead             │
│                                                              │
│  MyISAM        SQL Server   InnoDB      Rarely used         │
│  SQLite                     PostgreSQL                       │
└──────────────────────────────────────────────────────────────┘
```

**Explicit Locking in SQL:**

```sql
-- PostgreSQL: Row-level lock (SELECT FOR UPDATE)
BEGIN;
SELECT * FROM accounts WHERE id = 'A' FOR UPDATE;
-- Row 'A' is now locked — other transactions trying to UPDATE it will wait
UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
COMMIT;
-- Lock released

-- MySQL: Lock entire table (rarely needed)
LOCK TABLES accounts WRITE;
-- ... operations ...
UNLOCK TABLES;

-- Advisory locks (application-level coordination)
-- PostgreSQL:
SELECT pg_advisory_lock(12345);   -- Acquire lock with key 12345
-- ... critical section ...
SELECT pg_advisory_unlock(12345); -- Release lock
```

**Deadlocks:**

```
T1: Lock row A → wants to lock row B
T2: Lock row B → wants to lock row A

  T1 holds A, waits for B
  T2 holds B, waits for A
  → Neither can proceed → DEADLOCK! 💀

┌─────────┐    waiting for B    ┌─────────┐
│   T1    │────────────────────→│  Row B  │ ← held by T2
│ holds A │                     └─────────┘
└─────────┘                          │
     ↑                               │
     │          waiting for A        │
     └───────────────────────────────┘
              held by T1

Database detects deadlock:
  → Rolls back one transaction (the "victim")
  → The other proceeds
  → Application should retry the rolled-back transaction
```

**PostgreSQL Deadlock Detection:**

```sql
-- Set deadlock detection timeout
SET deadlock_timeout = '1s';  -- Check for deadlocks after 1 second

-- Monitor locks
SELECT pid, locktype, relation::regclass, mode, granted
FROM pg_locks
WHERE NOT granted;  -- Shows blocked queries

-- View waiting queries
SELECT blocked.pid AS blocked_pid,
       blocked.query AS blocked_query,
       blocking.pid AS blocking_pid,
       blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_locks bl ON blocked.pid = bl.pid AND NOT bl.granted
JOIN pg_locks al ON bl.locktype = al.locktype
    AND bl.relation = al.relation AND al.granted
JOIN pg_stat_activity blocking ON al.pid = blocking.pid;
```

---

#### Optimistic Concurrency — MVCC

**Multi-Version Concurrency Control (MVCC)** — instead of locking, the database keeps multiple versions of each row. Readers never block writers, and writers never block readers.

```
MVCC — How It Works:

Transaction T1 (read):           Transaction T2 (write):
  Snapshot at T=100               
                                  UPDATE accounts SET balance = 900
                                  WHERE id = 'A';
                                  (Creates new version, old version kept)

  SELECT balance WHERE id = 'A'  
  → Sees version from T=100       
  → Returns 1000 (old version)   
  → NOT blocked! ✅              COMMIT;
                                  (New version visible to future transactions)

Row Versions in Storage:
┌────────────────────────────────────────────────────────────┐
│  id='A'  Version 1: balance=1000  [created T=50, valid]   │
│  id='A'  Version 2: balance=900   [created T=105, valid]  │
└────────────────────────────────────────────────────────────┘

T1 (snapshot T=100) → sees Version 1 (created before snapshot)
T3 (snapshot T=110) → sees Version 2 (latest committed version)
```

**PostgreSQL MVCC Implementation:**

```sql
-- Every row in PostgreSQL has hidden system columns:
-- xmin: Transaction ID that created this row version
-- xmax: Transaction ID that deleted/updated this row version (0 if current)

SELECT xmin, xmax, ctid, * FROM accounts WHERE id = 'A';
-- xmin | xmax | ctid   | id | balance
-- 100  | 0    | (0,1)  | A  | 1000

-- After UPDATE in transaction 105:
-- xmin | xmax | ctid   | id | balance
-- 100  | 105  | (0,1)  | A  | 1000    ← old version (marked as dead)
-- 105  | 0    | (0,5)  | A  | 900     ← new version (current)
```

**VACUUM — Cleaning Up Old Versions:**

```
MVCC keeps old row versions → table grows over time (bloat)
VACUUM reclaims space from dead row versions

┌──────────────────────────────────────────────┐
│  Before VACUUM:                               │
│  Row 1: [live]                                │
│  Row 2: [dead - old version from T=50]        │
│  Row 3: [live]                                │
│  Row 4: [dead - old version from T=60]        │
│  Row 5: [live]                                │
│  Page utilization: 60% (40% is dead tuples)   │
│                                               │
│  After VACUUM:                                │
│  Row 1: [live]                                │
│  Row 2: [free space]                          │
│  Row 3: [live]                                │
│  Row 4: [free space]                          │
│  Row 5: [live]                                │
│  Page utilization: 60% (free space reusable)  │
└──────────────────────────────────────────────┘
```

```sql
-- Manual vacuum
VACUUM accounts;              -- Reclaim space (doesn't shrink file)
VACUUM FULL accounts;         -- Compact table (locks table, rewrites)
VACUUM ANALYZE accounts;      -- Vacuum + update query planner statistics

-- Autovacuum settings (postgresql.conf)
-- autovacuum = on                     (enabled by default)
-- autovacuum_vacuum_threshold = 50    (min dead tuples before vacuum)
-- autovacuum_vacuum_scale_factor = 0.2 (vacuum when 20% of rows are dead)

-- Monitor bloat
SELECT relname, n_live_tup, n_dead_tup,
       ROUND(n_dead_tup::numeric / NULLIF(n_live_tup, 0) * 100, 2) AS dead_pct
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

**Locking vs MVCC Comparison:**

| Aspect | Pessimistic (Locking) | Optimistic (MVCC) |
|--------|----------------------|-------------------|
| **Readers block writers** | ✅ Yes | ❌ No |
| **Writers block readers** | ✅ Yes | ❌ No |
| **Deadlocks possible** | ✅ Yes | Rare (write-write only) |
| **Storage overhead** | None | Multiple row versions |
| **Maintenance** | Lock manager | VACUUM/garbage collection |
| **Best for** | Write-heavy, short txns | Read-heavy, long txns |
| **Used by** | MySQL MyISAM, SQL Server (default) | PostgreSQL, MySQL InnoDB, Oracle |

---

### ACID vs BASE

| Property | ACID (SQL) | BASE (NoSQL) |
|----------|-----------|---------------|
| **Focus** | Correctness | Availability |
| **Consistency** | Strong (immediate) | Eventual |
| **Transactions** | Full ACID support | Limited or none |
| **Scale** | Vertical (scale up) | Horizontal (scale out) |
| **Use case** | Banking, inventory | Social feeds, analytics |

**BASE** stands for:
- **Basically Available**: System responds to every request (may be stale)
- **Soft State**: State can change without new input (replication lag)
- **Eventually Consistent**: Given enough time, all nodes converge

```
ACID vs BASE — Consistency Timeline:

ACID (Strong Consistency):
  Write ──→ ALL nodes updated ──→ Read returns latest
  Time: ███████████████████████████████████████████
        ↑ Write         ↑ Consistent everywhere

BASE (Eventual Consistency):
  Write ──→ Primary updated ──→ Replicas catching up... ──→ All consistent
  Time: ███████████████████████████████████████████
        ↑ Write    ↑ Some reads stale    ↑ Eventually consistent
                   (soft state window)

ACID: Client always sees latest data ✅ (slower writes)
BASE: Client may see stale data briefly ❌ (faster, more available)
```

**When to Choose:**
- Use ACID when data correctness is critical (financial, medical, booking)
- Use BASE when availability and scale matter more than instant consistency (social media, IoT)

---

### Database Storage Engines

The storage engine is the component that handles how data is physically stored, retrieved, and managed on disk.

```
┌────────────────────────────────────────────────────────────────┐
│                    STORAGE ENGINES                              │
├─────────────────────────┬──────────────────────────────────────┤
│                         │                                      │
│   B-Tree Based          │   LSM-Tree Based                     │
│   (Read-optimized)      │   (Write-optimized)                  │
│                         │                                      │
│   ┌─────────────────┐   │   ┌──────────────────────┐          │
│   │ InnoDB (MySQL)  │   │   │ RocksDB (MyRocks)    │          │
│   │ PostgreSQL      │   │   │ LevelDB              │          │
│   │ SQL Server      │   │   │ Cassandra             │          │
│   │ Oracle          │   │   │ HBase                 │          │
│   └─────────────────┘   │   │ CockroachDB (storage) │          │
│                         │   └──────────────────────┘          │
│   Data stored in        │   Data written to memtable,         │
│   sorted B-Tree pages   │   flushed to sorted SSTables,       │
│   on disk. Updates      │   compacted in background.          │
│   modify pages in       │   All writes are sequential         │
│   place (random I/O)    │   (append-only — very fast!)        │
│                         │                                      │
│   ✅ Fast reads         │   ✅ Fast writes                     │
│   ✅ Fast point lookups │   ✅ Great compression               │
│   ❌ Write amplification│   ❌ Read amplification               │
│   ❌ Random I/O writes  │   ❌ Compaction overhead              │
└─────────────────────────┴──────────────────────────────────────┘
```

| Aspect | B-Tree (InnoDB, PostgreSQL) | LSM-Tree (RocksDB, Cassandra) |
|--------|:---:|:---:|
| **Read performance** | Excellent | Good (may check multiple levels) |
| **Write performance** | Good | Excellent (sequential writes) |
| **Space efficiency** | Moderate (page fragmentation) | High (compacted SSTables) |
| **Use case** | OLTP, mixed workloads | Write-heavy, time-series, logs |
| **Write amplification** | Low-moderate | Moderate-high (compaction rewrites) |
| **Read amplification** | Low (1 B-Tree traversal) | Higher (check memtable + SSTables) |

For B-Tree internals, see [B-Tree and B+ Tree](b-tree-and-b-plus-tree.md). For LSM-Tree details, see [LSM Tree](lsm-tree.md).

---

### Query Processing Pipeline

How a SQL query goes from text to result:

```
SELECT name, balance FROM accounts WHERE balance > 1000 ORDER BY name;

┌─────────────────────────────────────────────────────────────────┐
│ Step 1: PARSER                                                  │
│   "SELECT name, balance FROM accounts WHERE balance > 1000"     │
│   → Parse SQL text into Abstract Syntax Tree (AST)              │
│   → Check syntax validity                                       │
│                                                                 │
│   AST:                                                          │
│     SELECT                                                      │
│     ├── columns: [name, balance]                                │
│     ├── FROM: accounts                                          │
│     ├── WHERE: balance > 1000                                   │
│     └── ORDER BY: name                                          │
└────────────────────┬────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Step 2: ANALYZER (Semantic Check)                               │
│   → Does table "accounts" exist?                                │
│   → Do columns "name", "balance" exist in accounts?             │
│   → Is "balance > 1000" a valid comparison?                     │
│   → Resolve types: balance is DECIMAL                           │
└────────────────────┬────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Step 3: QUERY OPTIMIZER                                         │
│   → Generate multiple execution plans                           │
│   → Estimate cost of each plan using statistics                 │
│                                                                 │
│   Plan A: Sequential Scan + Sort         Cost: 5000             │
│   Plan B: Index Scan (idx_balance) + Sort Cost: 120  ← Winner! │
│   Plan C: Index Scan (idx_name) + Filter  Cost: 3000            │
└────────────────────┬────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Step 4: EXECUTOR                                                │
│   → Execute Plan B:                                             │
│     1. Use idx_balance index to find rows where balance > 1000  │
│     2. Fetch matching rows from heap/data pages                 │
│     3. Sort results by name                                     │
│     4. Return result set to client                              │
└─────────────────────────────────────────────────────────────────┘
```

**EXPLAIN — See the Query Plan:**

```sql
-- PostgreSQL
EXPLAIN ANALYZE SELECT name, balance FROM accounts WHERE balance > 1000 ORDER BY name;

-- Output:
-- Sort  (cost=120.50..125.00 rows=1800 width=36) (actual time=1.2..1.5 rows=1800)
--   Sort Key: name
--   Sort Method: quicksort  Memory: 180kB
--   ->  Index Scan using idx_balance on accounts
--         (cost=0.29..50.00 rows=1800 width=36) (actual time=0.05..0.8 rows=1800)
--         Index Cond: (balance > 1000)
-- Planning Time: 0.15 ms
-- Execution Time: 1.8 ms

-- MySQL
EXPLAIN SELECT name, balance FROM accounts WHERE balance > 1000 ORDER BY name;
```

**Key EXPLAIN Terms:**

| Term | Meaning |
|------|---------|
| **Seq Scan** | Full table scan — reads every row (slow for large tables) |
| **Index Scan** | Uses index to find rows (fast) |
| **Index Only Scan** | All needed data is in the index — no table access (fastest) |
| **Bitmap Scan** | Builds a bitmap of matching pages, then fetches them |
| **Nested Loop** | For each row in table A, scan table B (JOINs) |
| **Hash Join** | Build hash table from smaller table, probe with larger |
| **Merge Join** | Both inputs sorted, merge in order (efficient for large sets) |
| **Sort** | Sort results (uses memory or disk if large) |

---

### Database Connections

Each connection to a database consumes resources. Understanding connection management is important for production systems.

```
Connection Lifecycle:
┌──────────┐   TCP handshake   ┌──────────────┐
│  Client  │──────────────────→│   Database   │
└──────────┘   + auth + setup  └──────┬───────┘
                (~100-500ms)          │
                                      │ Allocate:
                                      │   Memory (~10MB)
                                      │   Process/Thread
                                      │   Session state
                                      ↓
                               ┌──────────────┐
                               │  Connection  │ ← Ready for queries
                               │  (active)    │
                               └──────────────┘

Problem at scale:
  1000 application instances × 10 connections each = 10,000 connections
  10,000 × 10MB = 100GB RAM just for connections! 💥
```

**Connection Pooling:**

```
WITHOUT Pool:
  App → create connection → execute query → close connection
  App → create connection → execute query → close connection
  (100ms overhead per connection × 1000 requests/sec = 100 seconds wasted!)

WITH Pool:
  App → borrow connection from pool → execute query → return to pool
  App → borrow connection from pool → execute query → return to pool
  (Connections reused — near-zero overhead!)

┌─────────────────────┐
│   Connection Pool    │
│  ┌────┐ ┌────┐ ┌────┐│
│  │Conn│ │Conn│ │Conn││  ← Pre-created, reused
│  │ 1  │ │ 2  │ │ 3  ││
│  └────┘ └────┘ └────┘│
│  Pool size: 3-20      │
│  Max wait: 30s        │
└─────────────────────┘
```

**Application-Level Pooling:**

```python
# Python — SQLAlchemy connection pool
from sqlalchemy import create_engine

engine = create_engine(
    "postgresql://user:pass@localhost/mydb",
    pool_size=10,          # Maintain 10 connections
    max_overflow=20,       # Allow up to 30 total under burst
    pool_timeout=30,       # Wait 30s for a connection before error
    pool_recycle=1800,     # Recycle connections every 30 minutes
    pool_pre_ping=True,    # Test connection health before use
)
```

```java
// Java — HikariCP (fastest Java connection pool)
HikariConfig config = new HikariConfig();
config.setJdbcUrl("jdbc:postgresql://localhost/mydb");
config.setUsername("user");
config.setPassword("pass");
config.setMaximumPoolSize(10);
config.setMinimumIdle(5);
config.setConnectionTimeout(30000);  // 30 seconds
config.setIdleTimeout(600000);       // 10 minutes
config.setMaxLifetime(1800000);      // 30 minutes

HikariDataSource ds = new HikariDataSource(config);
```

For server-side pooling (PgBouncer, ProxySQL), see [Scaling and Replication](scaling-and-replication.md).

---

### Data Modeling Fundamentals

#### Schema Design Process

```
1. Identify Entities:
   Users, Orders, Products, Categories

2. Define Relationships:
   Users ──(1:N)──→ Orders
   Orders ──(N:M)──→ Products (via order_items)
   Products ──(N:1)──→ Categories

3. Normalize (eliminate redundancy):
   ┌──────────┐     ┌──────────────┐     ┌──────────────┐
   │  users    │     │   orders      │     │  order_items  │
   ├──────────┤     ├──────────────┤     ├──────────────┤
   │ id (PK)  │←──┐ │ id (PK)      │←──┐ │ id (PK)      │
   │ name     │   └─│ user_id (FK) │   └─│ order_id (FK)│
   │ email    │     │ total        │     │ product_id   │
   └──────────┘     │ status       │     │ quantity     │
                    │ created_at   │     │ unit_price   │
                    └──────────────┘     └──────────────┘

                    ┌──────────────┐     ┌──────────────┐
                    │  products     │     │  categories   │
                    ├──────────────┤     ├──────────────┤
                    │ id (PK)      │  ┌─→│ id (PK)      │
                    │ name         │  │  │ name         │
                    │ price        │  │  │ parent_id    │
                    │ category_id──│──┘  └──────────────┘
                    └──────────────┘

4. Add indexes on foreign keys and frequently queried columns
5. Consider denormalization for read-heavy paths (see Denormalization)
```

#### Relationships

```sql
-- One-to-Many: User has many orders
CREATE TABLE users (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE orders (
    id         SERIAL PRIMARY KEY,
    user_id    INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    total      DECIMAL(10,2) NOT NULL,
    status     VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Many-to-Many: Orders contain many products, products in many orders
CREATE TABLE order_items (
    id         SERIAL PRIMARY KEY,
    order_id   INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id),
    quantity   INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL,
    UNIQUE (order_id, product_id)  -- No duplicate product in same order
);

-- One-to-One: User has one profile
CREATE TABLE user_profiles (
    user_id INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    bio     TEXT,
    avatar  VARCHAR(500),
    website VARCHAR(255)
);
```

#### ON DELETE Actions

```sql
-- What happens when a referenced row is deleted?

ON DELETE CASCADE    -- Delete child rows too
ON DELETE SET NULL   -- Set FK column to NULL
ON DELETE RESTRICT   -- Prevent deletion (default)
ON DELETE SET DEFAULT -- Set FK to column default
ON DELETE NO ACTION  -- Same as RESTRICT (checked at end of statement)

-- Example:
-- Deleting a user cascades to their orders and profile
DELETE FROM users WHERE id = 1;
-- → Deletes user 1
-- → Deletes all orders WHERE user_id = 1
-- → Deletes user_profiles WHERE user_id = 1
```

---

### Database Performance Checklist

```
┌─────────────────────────────────────────────────────────────────┐
│              PERFORMANCE OPTIMIZATION HIERARCHY                  │
│              (try from top to bottom)                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. SCHEMA DESIGN                                               │
│     ✅ Proper normalization (then selective denormalization)     │
│     ✅ Correct data types (INT vs BIGINT, VARCHAR vs TEXT)       │
│     ✅ Foreign key constraints                                  │
│                                                                 │
│  2. INDEXING                                                    │
│     ✅ Index columns in WHERE, JOIN, ORDER BY                   │
│     ✅ Composite indexes for multi-column filters               │
│     ✅ Don't over-index (hurts writes)                          │
│     → See: Indexing                                             │
│                                                                 │
│  3. QUERY OPTIMIZATION                                          │
│     ✅ Use EXPLAIN ANALYZE to find slow queries                 │
│     ✅ Avoid SELECT * (fetch only needed columns)               │
│     ✅ Use LIMIT for pagination                                 │
│     ✅ Avoid N+1 query problems (use JOINs or batch)            │
│                                                                 │
│  4. CACHING                                                     │
│     ✅ Application-level cache (Redis, Memcached)               │
│     ✅ Query result cache                                       │
│     ✅ Materialized views for complex reports                   │
│                                                                 │
│  5. CONNECTION MANAGEMENT                                       │
│     ✅ Connection pooling (HikariCP, PgBouncer)                 │
│     ✅ Appropriate pool size                                    │
│                                                                 │
│  6. SCALING                                                     │
│     ✅ Read replicas for read-heavy workloads                   │
│     ✅ Vertical scaling (bigger machine)                        │
│     ✅ Sharding for write-heavy / massive datasets              │
│     → See: Scaling and Replication, Sharding                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**The N+1 Query Problem:**

```python
# ❌ N+1 Problem: 1 query for users + N queries for orders
users = db.execute("SELECT * FROM users").fetchall()      # 1 query
for user in users:
    orders = db.execute(                                    # N queries!
        "SELECT * FROM orders WHERE user_id = %s", (user.id,)
    ).fetchall()
# Total: 101 queries for 100 users 💀

# ✅ Solution: Single JOIN query
results = db.execute("""
    SELECT u.id, u.name, o.id AS order_id, o.total
    FROM users u
    LEFT JOIN orders o ON u.id = o.user_id
""").fetchall()
# Total: 1 query ✅

# ✅ Alternative: Batch loading
users = db.execute("SELECT * FROM users").fetchall()
user_ids = [u.id for u in users]
orders = db.execute(
    "SELECT * FROM orders WHERE user_id = ANY(%s)", (user_ids,)
).fetchall()
# Total: 2 queries ✅
```

---

### Summary

```
Database Fundamentals Map:

┌─────────────────────────────────────────────────────────────────┐
│                        DATABASE                                  │
├──────────────┬──────────────┬──────────────┬────────────────────┤
│  Storage     │ Transactions │ Concurrency  │ Performance        │
│              │              │              │                    │
│ B-Tree       │ ACID         │ Locks        │ Indexing           │
│ LSM-Tree     │ Isolation    │ MVCC         │ Query Optimization │
│ WAL          │ Levels       │ Deadlocks    │ Connection Pooling │
│ Pages/Blocks │ Savepoints   │              │ Caching            │
│              │ BASE         │              │ Denormalization    │
├──────────────┴──────────────┴──────────────┴────────────────────┤
│  Scaling: Replication → Caching → Sharding → NewSQL             │
└─────────────────────────────────────────────────────────────────┘
```

**Key Takeaways:**

| Concept | Summary |
|---------|---------|
| **ACID** | Atomicity + Consistency + Isolation + Durability — foundation of relational DBs |
| **Isolation Levels** | Trade-off between safety and performance; Read Committed is the sweet spot |
| **WAL** | Write-Ahead Log ensures durability — changes logged before applied |
| **MVCC** | Multiple row versions allow reads and writes without blocking each other |
| **Locking** | Pessimistic concurrency — explicit locks prevent conflicts but cause waits |
| **Deadlocks** | Circular lock dependencies — DB detects and kills one transaction |
| **BASE** | Eventually consistent alternative to ACID — availability over correctness |
| **Storage Engines** | B-Tree (read-optimized) vs LSM-Tree (write-optimized) |
| **Query Pipeline** | Parse → Analyze → Optimize → Execute — EXPLAIN shows the plan |
| **N+1 Problem** | Most common performance pitfall — use JOINs or batch loading |
