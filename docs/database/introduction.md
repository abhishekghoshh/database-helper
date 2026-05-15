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

### ACID Properties — The Four Guarantees

**Atomicity** — All or Nothing
- A transaction is treated as a single unit. If any part fails, the entire transaction is rolled back.
- Example: In a bank transfer, if the credit fails, the debit is reversed.

**Consistency** — Valid State to Valid State
- A transaction takes the database from one valid state to another. All constraints (foreign keys, unique constraints, checks) must be satisfied after the transaction.
- Example: If a column has a `NOT NULL` constraint, no transaction can leave it NULL.

**Isolation** — Concurrent Transactions Don't Interfere
- Multiple transactions running simultaneously behave as if they run sequentially. One transaction cannot see the partial results of another.
- **Isolation Levels** (from weakest to strongest):
  - **Read Uncommitted**: Can see uncommitted data (dirty reads)
  - **Read Committed**: Only sees committed data (default in PostgreSQL)
  - **Repeatable Read**: Same query returns same results within a transaction (default in MySQL InnoDB)
  - **Serializable**: Full isolation, transactions appear sequential (slowest, safest)

**Durability** — Committed Data Survives Crashes
- Once a transaction is committed, the data persists even if the system crashes, power goes out, or hardware fails.
- Achieved through Write-Ahead Logging (WAL) — changes are written to a log before being applied.

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

**When to Choose:**
- Use ACID when data correctness is critical (financial, medical, booking)
- Use BASE when availability and scale matter more than instant consistency (social media, IoT)

---

### Quick Reference

Organized collection of structured data.

**ACID Properties:**
- **Atomicity**: All or nothing transactions
- **Consistency**: Data integrity maintained
- **Isolation**: Concurrent transactions don't interfere
- **Durability**: Committed data persists

**BASE (NoSQL alternative):**
- **Basically Available**: System available most of the time
- **Soft state**: State may change over time
- **Eventual consistency**: System becomes consistent eventually
