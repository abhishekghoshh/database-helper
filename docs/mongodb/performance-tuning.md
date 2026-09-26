# Performance Tuning

## Query Optimization

Query optimization involves shaping queries and the underlying data/index design so MongoDB can satisfy requests with minimal document scanning, primarily by ensuring queries are covered by appropriate indexes and by using `explain()` to inspect the query planner's chosen execution plan (`IXSCAN` vs. the much slower `COLLSCAN`). Common techniques include projecting only needed fields, avoiding unnecessary `$where`/regex-without-anchors, and structuring compound indexes to match query patterns (equality, sort, range — the "ESR rule").

```javascript
// Inspect the execution plan for a query
db.orders.find({ customerId: "C123", status: "shipped" })
  .sort({ orderDate: -1 })
  .explain("executionStats")
```

**Interview Questions:**
- What is the difference between `COLLSCAN` and `IXSCAN` in an `explain()` output? — `COLLSCAN` indicates MongoDB scanned every document in the collection to find matches, while `IXSCAN` indicates it used an index to efficiently locate candidate documents, typically examining far fewer entries.
- What is the ESR (Equality, Sort, Range) rule for compound index design? — The ESR rule recommends ordering compound index fields with equality filters first, then sort fields, then range filters, so the index can most efficiently narrow, order, and bound the result set in a single traversal.
- How would you diagnose why a query is running slowly in production? — Use the profiler or slow query log to identify the offending query, then run `explain("executionStats")` on it to check whether it's using an appropriate index, examining far more documents than it returns, or missing an index entirely.

## Index Optimization

Index optimization is the ongoing practice of ensuring the right indexes exist (supporting actual query patterns) without over-indexing, since every index adds write overhead and memory/disk usage. This includes removing unused indexes (identified via `$indexStats`), preferring compound indexes over multiple single-field indexes when queries combine filters, and considering partial or sparse indexes to reduce index size for selective query patterns.

```javascript
// Find unused indexes based on collected usage stats
db.orders.aggregate([{ $indexStats: {} }])

// Create a partial index that only indexes shipped orders
db.orders.createIndex(
  { orderDate: 1 },
  { partialFilterExpression: { status: "shipped" } }
)
```

**Advantages:**
- Well-tuned indexes dramatically reduce query latency and CPU usage
- Partial/sparse indexes reduce index size and memory footprint for selective queries

**Disadvantages:**
- Every additional index slows down writes (inserts/updates/deletes) and consumes RAM/disk
- Redundant or unused indexes waste resources without benefit

**Interview Questions:**
- How would you identify unused indexes in a production collection? — Run the `$indexStats` aggregation stage to see each index's usage count since the last restart, and any index showing zero or negligible usage over a representative period is a candidate for removal.
- What's the trade-off of adding more indexes to speed up reads? — More indexes speed up the specific reads they support but add overhead to every insert, update, and delete since each index must also be maintained, along with increased RAM and disk consumption.
- When would you use a partial index instead of a full index? — Use a partial index when queries consistently filter on a specific condition (e.g., only "shipped" orders) so only the relevant subset of documents needs indexing, reducing index size and write overhead compared to indexing the entire collection.

## Connection Pooling

Connection pooling allows a MongoDB driver to reuse a set of established TCP connections across many operations instead of opening/closing a new connection per request, dramatically reducing connection setup overhead (including TLS handshakes) under load. Drivers expose pool size settings (e.g. `maxPoolSize`, `minPoolSize`) that should be tuned relative to expected application concurrency and the server's `maxIncomingConnections` limit.

```java
// Spring Boot application.properties: tuning the MongoDB connection pool
spring.data.mongodb.uri=mongodb://localhost:27017/ecommerceDb?maxPoolSize=100&minPoolSize=10&maxIdleTimeMS=60000
```

**Advantages:**
- Reduces latency from repeated connection establishment
- Bounds resource usage on both client and server sides

**Disadvantages:**
- Undersized pools cause request queuing/timeouts under concurrent load
- Oversized pools across many application instances can overwhelm the server's connection limits

**Interview Questions:**
- Why is connection pooling important for MongoDB driver performance? — Connection pooling reuses established TCP (and TLS) connections across operations, avoiding the latency and CPU cost of repeatedly opening and closing connections for every request under load.
- What happens if `maxPoolSize` is set too low for a high-concurrency service? — Operations queue up waiting for an available connection from the pool, increasing request latency and potentially causing timeouts under high concurrent load.
- How would you size connection pools across multiple application instances sharing one MongoDB cluster? — Size each instance's pool so the sum across all application instances stays comfortably within the MongoDB server's `maxIncomingConnections` limit, accounting for expected concurrency per instance and the total number of instances that will connect simultaneously.

## Bulk Writes

Bulk write operations let a client send multiple insert, update, or delete operations in a single request, reducing network round-trips and improving throughput compared to issuing each operation individually. MongoDB supports ordered bulk writes (stop on first error, operations execute in sequence) and unordered bulk writes (continue past errors, operations may execute in any order, allowing more parallelism).

```javascript
db.orders.bulkWrite([
  { insertOne: { document: { customerId: "C1", total: 20 } } },
  { updateOne: { filter: { customerId: "C2" }, update: { $set: { status: "shipped" } } } },
  { deleteOne: { filter: { customerId: "C3" } } }
], { ordered: false })
```

**Differences:**

| Mode | Error Behavior | Execution Order |
|---|---|---|
| Ordered (default) | Stops at first error | Sequential, guaranteed order |
| Unordered | Continues past errors, reports all at the end | May execute in parallel, no order guarantee |

**Interview Questions:**
- What is the difference between ordered and unordered bulk writes? — Ordered bulk writes execute sequentially and stop at the first error, preserving the guaranteed order of operations, while unordered bulk writes continue past errors and may execute in any order, reporting all successes and failures at the end.
- Why would unordered bulk writes generally perform better? — Unordered bulk writes can be executed in parallel and don't need to preserve strict sequencing, allowing the server to process them more efficiently than the sequential, stop-on-error behavior of ordered writes.
- What happens to remaining operations in an ordered bulk write after one fails? — In an ordered bulk write, all operations after the first failure are not executed at all; the batch stops immediately upon encountering the error.

## Batch Processing

Batch processing refers to structuring application workloads to read, transform, and write data in chunks rather than one document at a time, reducing overhead and improving throughput for large-scale operations like ETL jobs, migrations, or nightly reporting. This is typically combined with cursor batching (`cursor.batchSize()`) on reads and bulk writes on the write side, and is a common pattern implemented with Spring Batch when integrating with MongoDB in Spring Boot applications.

```java
// Spring Data MongoDB: reading in batches with a cursor batch size
MongoCursor<Document> cursor = collection.find()
    .batchSize(500)
    .iterator();
```

**Advantages:**
- Reduces per-document network and processing overhead for large datasets
- Pairs naturally with bulk writes for efficient large-scale updates

**Disadvantages:**
- Larger batch sizes increase memory usage per batch
- Requires careful error handling/retry logic since a failure mid-batch can leave partial progress

**Interview Questions:**
- Why is batch processing more efficient than per-document processing for large datasets? — Processing data in batches amortizes network round-trip and per-operation overhead across many documents at once, rather than paying that fixed cost for every single document individually.
- How does cursor `batchSize` affect memory usage and round-trips? — A larger `batchSize` retrieves more documents per network round-trip, reducing the number of round-trips needed but increasing the memory required to hold each batch on the client.
- How would you handle a failure partway through processing a large batch job? — Design the job to be idempotent and track progress (e.g., a checkpoint or last-processed ID) so it can safely resume from where it left off, or use bulk writes with `ordered: false` combined with per-item error handling and retry logic to isolate failures to individual items.

## Profiling

The MongoDB database profiler captures detailed information about executed operations (queries, updates, commands) including execution time, and stores them in the `system.profile` capped collection, enabling analysis of what's actually running against the database and how expensive each operation is. It has three levels: `0` (off), `1` (log slow operations above a threshold), and `2` (log every operation — very verbose, typically only for short-term debugging).

```javascript
// Enable profiling for operations slower than 100ms
db.setProfilingLevel(1, { slowms: 100 })

// Review the slowest recent operations
db.system.profile.find().sort({ millis: -1 }).limit(10)
```

**Advantages:**
- Provides ground-truth visibility into actual query performance in a live system
- Level 1 with a threshold has low overhead, safe for production use

**Disadvantages:**
- Level 2 (profile everything) adds significant overhead and is unsuitable for sustained production use
- `system.profile` is a capped collection, so old entries roll off and must be exported for long-term analysis

**Interview Questions:**
- What are the differences between profiling levels 0, 1, and 2? — Level 0 disables profiling entirely, level 1 logs only operations slower than a configurable threshold (`slowms`), and level 2 logs every single operation regardless of duration, which is very verbose and typically reserved for short-term debugging.
- Where does MongoDB store profiling data, and what are the implications of that? — Profiling data is stored in the `system.profile` capped collection within each database, meaning older entries are automatically overwritten once the collection reaches its size limit, so data must be exported or analyzed promptly for long-term trend analysis.
- What overhead considerations apply to running the profiler in production? — Level 1 with a sensible threshold has low overhead and is generally safe for production, but level 2 logs every operation and can noticeably degrade performance and consume significant disk space, so it should only be used briefly and deliberately.

## Slow Query Analysis

Slow query analysis is the practice of identifying, inspecting, and fixing operations that exceed acceptable latency thresholds, typically by combining the database profiler or `mongod` log's slow-query entries (operations exceeding `slowms`, default 100ms) with `explain()` to understand why a specific query is slow (missing index, poor index selectivity, large result sets, or query patterns causing collection scans).

```bash
# Search the mongod log for slow query entries
grep -i "COMMAND" /var/log/mongodb/mongod.log | grep -i "durationMillis" | awk '$NF+0 > 200'
```

**Interview Questions:**
- What is a practical workflow for diagnosing a slow query in production? — First identify the offending query via the profiler or slow-query log entries exceeding `slowms`, then run `explain("executionStats")` on it to see whether it's using an index efficiently, and finally add or adjust indexes (or rewrite the query) based on what the plan reveals.
- How does `explain("executionStats")` help identify the root cause of slowness? — It reveals the chosen execution plan (`IXSCAN` vs `COLLSCAN`), the number of documents examined versus returned, and time spent, making it clear whether the query is missing an index, has poor selectivity, or is scanning far more data than necessary.
- What are common root causes of slow queries in MongoDB (missing indexes, large scans, poor shard key, etc.)? — Common causes include missing or poorly designed indexes forcing collection scans, queries that don't align with the ESR rule for compound indexes, an inefficient shard key causing scatter-gather queries across all shards, and unbounded result sets lacking pagination.

## Memory Considerations

MongoDB performance is heavily influenced by how much of the "working set" (the data and indexes actively accessed) fits in available memory — primarily the WiredTiger cache, but also the OS page cache for compressed on-disk pages. When the working set exceeds available memory, MongoDB must read from disk more frequently, increasing latency; sizing RAM appropriately, using efficient data types/indexes, and monitoring page faults and cache eviction rates are core parts of capacity planning.

```javascript
// Check for page faults, an indicator of memory pressure
db.serverStatus().extra_info.page_faults
```

**Advantages:**
- Ensuring the working set fits in memory is one of the single biggest performance levers available
- Monitoring memory metrics proactively helps catch capacity issues before they cause outages

**Disadvantages:**
- Simply adding more RAM has diminishing returns if data models or indexes are inefficient
- Under-provisioned memory on write-heavy sharded clusters can cause cascading replication lag

**Interview Questions:**
- What is the "working set" and why does its relationship to available RAM matter so much for performance? — The working set is the subset of data and indexes actively accessed by the application's typical workload; when it fits entirely in the WiredTiger cache/RAM, reads are served from memory, but once it exceeds available memory, MongoDB must fetch pages from disk far more often, significantly increasing latency.
- What metrics would you monitor to detect memory pressure in MongoDB? — Monitor page fault counts (`serverStatus().extra_info.page_faults`), WiredTiger cache eviction rate, and cache usage percentage, all of which rise when the working set no longer comfortably fits in available memory.
- How would you approach capacity planning for RAM on a new MongoDB deployment? — Estimate the expected working set size (active data plus indexes) based on projected data volume and access patterns, provision RAM with headroom above that estimate, and monitor page faults and cache eviction rates post-launch to validate and adjust sizing over time.
