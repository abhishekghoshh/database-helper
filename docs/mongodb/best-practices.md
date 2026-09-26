# Best Practices

## Schema Design Best Practices

MongoDB schema design should be driven by application query patterns rather than pure normalization — "data that is accessed together should be stored together." This means starting from the application's most frequent and performance-critical queries, then modeling documents to satisfy them with minimal lookups.

**Interview Questions:**
- What does "design for your queries, not your data" mean in MongoDB schema design? — It means modeling documents around how the application will read and write data (which fields are queried together, sorted, or updated) rather than pursuing normalization for its own sake, so the schema minimizes lookups and matches real access patterns.
- How would you approach schema design differently for MongoDB versus a relational database? — In a relational database you normalize first and optimize queries later with joins, whereas in MongoDB you start from the application's query patterns and choose embedding or referencing per relationship to satisfy those queries efficiently, accepting some denormalization.

## Embedding vs Referencing

Embedding stores related data as nested sub-documents within a single parent document, favoring read performance and atomicity for data that is always accessed together. Referencing stores related data in a separate collection and links via an `_id`, favoring flexibility and avoiding document growth/duplication for data that is large, frequently changing, or shared across many parents.

**Differences:**

| Aspect | Embedding | Referencing |
|---|---|---|
| Read performance | Single query, no join | Requires `$lookup` or a second query |
| Data duplication | Higher (duplicated across parents) | None (single source of truth) |
| Document size growth | Can hit 16MB limit if unbounded | Unaffected by related data size |
| Atomic updates | Atomic within one document | Not atomic across documents (needs transaction) |
| Best for | 1-to-few, data accessed together | 1-to-many/many-to-many, independently updated data |

**Interview Questions:**
- What criteria would you use to decide between embedding and referencing for a one-to-many relationship? — Consider whether the related data is always accessed together with the parent (favoring embedding), how large and unbounded the related collection could grow, whether it needs to be updated/queried independently, and whether it's shared across multiple parents (favoring referencing).
- How does the 16MB document size limit influence this decision? — If embedding an unbounded or fast-growing array risks approaching the 16MB BSON document limit, referencing (or patterns like Subset/Bucket) should be used instead to keep documents bounded in size.
- How would you model a many-to-many relationship (e.g. students and courses) in MongoDB? — Typically use referencing with an array of IDs on one or both sides (e.g. a `courseIds` array on the student document), or a separate join/linking collection when the relationship itself carries additional attributes (like enrollment date).

## Index Design

Effective index design follows the ESR (Equality, Sort, Range) rule for compound indexes: place equality-matched fields first, sort fields second, and range-filtered fields last. Every index should be justified by an actual query pattern — unused indexes only add write overhead and storage cost.

```javascript
// Query: find active orders for a customer, sorted by date, within a price range
db.orders.find({ customerId: 'c1', status: 'active', total: { $gte: 100 } }).sort({ orderDate: -1 })

// ESR-compliant compound index: Equality(customerId,status), Sort(orderDate), Range(total)
db.orders.createIndex({ customerId: 1, status: 1, orderDate: -1, total: 1 })
```

**Interview Questions:**
- What is the ESR rule and how does it guide compound index field ordering? — ESR stands for Equality, Sort, Range: compound index fields should be ordered with equality-matched fields first, sort fields second, and range-filtered fields last, so the index can narrow results with equality, satisfy the sort order, then scan the range efficiently.
- How would you identify unused or redundant indexes in a production collection? — Use `$indexStats` (or the Atlas Performance Advisor) to see index usage counters over time, and flag indexes with zero or near-zero usage, or indexes that are a strict prefix subset of another compound index, as candidates for removal.
- What is index intersection and why shouldn't you rely on it instead of proper compound indexes? — Index intersection lets MongoDB combine two separate single-field indexes to satisfy a query, but it's generally less efficient than a single well-ordered compound index and isn't used for sorting, so compound indexes matching the actual query pattern should be preferred.

## Collection Design

Collection design decisions include when to split data into multiple collections versus a single collection with a discriminator field, how to handle time-series data (using time-series collections since MongoDB 5.0), and how to avoid unbounded collection growth patterns that hurt performance.

**Interview Questions:**
- When would you use MongoDB's native time-series collections instead of a manually bucketed schema? — Use native time-series collections (available since MongoDB 5.0) when you want MongoDB to automatically handle bucketing, compression, and time-based indexing for you, avoiding the manual complexity of designing and maintaining your own Bucket Pattern schema.
- What are the trade-offs of using a single collection with a `type` discriminator field versus multiple collections? — A single collection with a discriminator simplifies polymorphic queries and shared indexes but can mix unrelated document shapes and make schema validation/indexing less targeted, while multiple collections give cleaner separation and indexing at the cost of needing application-level joins for cross-type queries.

## Shard Key Selection

The shard key determines how data is distributed across shards in a sharded cluster, and it cannot be changed (prior to resharding support) once chosen, making it one of the most consequential early decisions. A good shard key has high cardinality, even distribution of writes, and aligns with common query patterns to avoid scatter-gather queries.

**Advantages of a good shard key:**
- Even data and write distribution across shards
- Queries can be targeted to specific shards instead of broadcasting to all

**Disadvantages of a poor shard key:**
- Hotspots on a single shard (monotonically increasing keys like timestamps or ObjectIds)
- Scatter-gather queries across all shards, hurting performance

**Interview Questions:**
- What makes a good versus a bad shard key choice? — A good shard key has high cardinality, distributes writes evenly across shards, and aligns with common query patterns so queries can target specific shards; a bad shard key has low cardinality, creates write hotspots, or forces scatter-gather queries across all shards.
- Why is a monotonically increasing field like a timestamp often a poor shard key on its own? — Because all new writes have ever-increasing values, they all land on the same shard (the one owning the current highest range), creating a write hotspot instead of distributing load evenly across the cluster.
- What is resharding and when would you need it? — Resharding is the process (supported since MongoDB 5.0) of changing a collection's shard key after the fact; it's needed when the original shard key causes hotspots or uneven distribution and the data must be redistributed without a full manual migration.

## Performance Optimization

Performance tuning in MongoDB revolves around ensuring queries use appropriate indexes (verified with `explain()`), keeping the working set within available RAM/WiredTiger cache, using projections to limit returned fields, and using the aggregation pipeline efficiently (filtering early with `$match` before expensive stages).

```javascript
// Analyze query execution to check for collection scans (COLLSCAN)
db.orders.find({ status: 'active' }).explain('executionStats')
```

**Interview Questions:**
- How would you use `explain()` to diagnose a slow query? — Run the query with `.explain('executionStats')` to inspect whether it used an index scan (`IXSCAN`) or a full collection scan (`COLLSCAN`), how many documents were examined versus returned, and total execution time, then adjust indexes accordingly.
- What is the significance of placing `$match` early in an aggregation pipeline? — Placing `$match` as early as possible lets MongoDB use indexes to filter out unneeded documents before later, more expensive stages (like `$group` or `$lookup`) run, drastically reducing the amount of data processed downstream.
- How does working-set size relative to available memory affect performance? — If the frequently accessed data and indexes (the working set) fit within the WiredTiger cache/RAM, reads are served from memory; once the working set exceeds available memory, MongoDB must fetch pages from disk more often, significantly increasing latency.

## Security Best Practices

MongoDB production security best practices include enabling authentication and role-based access control (RBAC), enabling TLS/SSL for data in transit, encrypting data at rest, restricting network access via firewalls/VPC peering and binding to specific IPs, enabling auditing, and following the principle of least privilege for database users/roles.

**Interview Questions:**
- What steps would you take to secure a MongoDB deployment before going to production? — Enable authentication and RBAC, enforce TLS/SSL for all connections, enable encryption at rest, restrict network access via firewalls/VPC peering and IP binding, enable auditing, and apply least-privilege roles to all database users.
- What is the principle of least privilege and how does it apply to MongoDB user roles? — It means granting each user or application only the minimum permissions needed for its function (e.g. read-only or restricted to specific collections) rather than broad admin roles, limiting the damage a compromised credential can cause.
- How does field-level or client-side field level encryption differ from encryption at rest? — Encryption at rest protects the entire data files on disk transparently to the application, while field-level/client-side field level encryption (CSFLE) encrypts specific sensitive fields before they leave the client, so even database administrators or anyone with disk/backup access cannot read those fields without the client-held keys.
