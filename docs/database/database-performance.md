# Database Performance Concepts

## Theory

### Database Bottlenecks

A bottleneck is any resource or operation that limits the overall throughput of a database system — even if every other component is fast, the system as a whole is only as fast as its slowest constraint. Common bottlenecks include CPU saturation from complex query plans, disk I/O contention, lock contention on hot rows/tables, insufficient memory causing excessive disk reads, network latency between app and DB, and poorly designed indexes causing full table scans. Identifying bottlenecks typically involves query execution plans, slow query logs, and monitoring tools (CPU, I/O wait, lock wait times).

- **Advantages of identifying bottlenecks early:** targeted fixes, better capacity planning, predictable scaling
- **Disadvantages of ignoring them:** cascading slowdowns, timeouts, poor user experience under load

### Connection Management

Connection management refers to how an application opens, uses, and closes connections to the database. Each connection consumes server-side resources (memory, file handles, sometimes a dedicated process/thread), so uncontrolled connection creation can exhaust database limits and degrade performance. Proper connection management includes closing/releasing connections promptly, setting timeouts, and avoiding one-connection-per-request patterns without pooling.

### Connection Pooling (Concept)

Connection pooling maintains a pre-initialized set of reusable database connections that application threads borrow and return, instead of opening a new physical connection for every request. This avoids the overhead of TCP handshake, authentication, and session setup on every query, dramatically improving throughput under concurrent load.

```yaml
# Example: HikariCP connection pool configuration
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
```

- **Advantages:** reduced connection setup overhead, controlled resource usage, better handling of traffic spikes
- **Disadvantages:** pool sizing is non-trivial (too small causes waiting, too large exhausts DB resources), stale/leaked connections can silently reduce pool capacity

### Caching Basics

Caching stores frequently accessed data in a faster storage layer (in-memory, closer to the application) to avoid repeated expensive database round-trips. Caches can live at multiple layers: application-level (e.g., local in-process cache), distributed cache (e.g., Redis/Memcached), or database-level (query cache, buffer pool). The main challenge is cache invalidation — ensuring cached data doesn't go stale when the underlying data changes.

- **Advantages:** lower latency, reduced database load, better scalability for read-heavy workloads
- **Disadvantages:** risk of serving stale data, added architectural complexity, cache invalidation bugs

### Read vs Write Performance

Read and write operations have different performance characteristics and often require different optimization strategies. Reads can be scaled horizontally via replicas and caching since they don't mutate state, while writes are harder to scale because they must maintain consistency and are typically bound to a single primary node (in traditional RDBMS setups). Indexes speed up reads but slow down writes (since indexes must be updated on every insert/update/delete), representing a classic trade-off.

| Aspect | Reads | Writes |
|---|---|---|
| Scalability | Easy (replicas, caching) | Harder (single source of truth) |
| Impact of indexes | Faster lookups | Slower due to index maintenance |
| Consistency concern | Can tolerate staleness (replicas) | Must be strongly consistent |

### Bulk Operations

Bulk operations perform inserts, updates, or deletes on many rows in a single statement or batch, rather than issuing one statement per row. Databases can optimize bulk operations internally (single transaction log entry, fewer round trips, batched index updates), making them far more efficient than row-by-row processing from the application.

```sql
-- Bulk insert example
INSERT INTO orders (customer_id, amount, status)
VALUES
  (101, 250.00, 'PENDING'),
  (102, 99.50, 'PENDING'),
  (103, 430.75, 'PENDING');
```

- **Advantages:** fewer network round-trips, reduced transaction overhead, better throughput
- **Disadvantages:** larger transactions can hold locks longer, harder to handle partial failures gracefully

### Batch Processing

Batch processing groups a large number of operations to be executed together, often on a schedule (e.g., nightly jobs), rather than processing each item immediately as it arrives. This is common for ETL jobs, report generation, and reconciliation tasks. Batch size tuning matters: too large a batch risks long transactions and memory pressure; too small negates the efficiency gains.

- **Advantages:** efficient resource utilization, predictable load windows, simpler error recovery (retry failed batch)
- **Disadvantages:** not suitable for real-time requirements, potential for large resource spikes during batch windows

### Interview Questions

- **Q: How would you diagnose a database performance bottleneck in production?**
  A: Check slow query logs and execution plans first, then monitor CPU/I/O/lock wait metrics, and correlate spikes with recent deploys or traffic patterns; use `EXPLAIN ANALYZE` to see if queries are doing full scans or missing indexes.
- **Q: Why is connection pooling important, and what happens if the pool size is misconfigured?**
  A: It reuses expensive-to-create connections; too small a pool causes request queuing/timeouts under load, too large a pool can exhaust the database's max connection limit and degrade server performance.
- **Q: What's the trade-off between adding more indexes and write performance?**
  A: Indexes speed up reads but every write must also update each index, increasing write latency and storage — indexes should be added based on actual query patterns, not preemptively.
- **Q: When would you choose caching over adding a read replica?**
  A: Caching is better for frequently-read, rarely-changing data with tolerable staleness (e.g., product catalog); read replicas are better when you need full relational query capability with near-real-time consistency.
- **Q: How do bulk operations improve performance compared to row-by-row processing?**
  A: They reduce network round trips and transaction/log overhead by batching many rows into fewer statements, letting the database optimize execution as a set operation.
- **Q: What risks come with very large batch or bulk transactions?**
  A: Long-held locks blocking other transactions, increased rollback segment/log usage, and larger blast radius if a failure occurs mid-batch.
- **Q: How would you design a system to handle a sudden spike in read traffic without touching write capacity?**
  A: Introduce caching (e.g., Redis) in front of the DB and/or add read replicas to offload SELECT queries from the primary, keeping writes isolated to the primary node.

