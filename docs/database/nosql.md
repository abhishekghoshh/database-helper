# NoSQL


## Youtube 


## Short Videos

- [Why does NoSQL exist? (MongoDB, Cassandra) | System Design](https://www.youtube.com/watch?v=YDR3D2bsv9Y)
- [The Untold Story of NoSQL Databases](https://www.youtube.com/watch?v=jnKy3yYHVsQ)
-
- [How do NoSQL databases work? Simply Explained!](https://www.youtube.com/watch?v=0buKQHokLK8)
- [The Secret Sauce Behind NoSQL: LSM Tree](https://www.youtube.com/watch?v=I6jB0nM9SKU)
- [Cassandra vs MongoDB vs HBase | Difference Between Popular NoSQL Databases | Edureka](https://www.youtube.com/watch?v=QlqylUeqeis)




## Theory

Flexible schema databases for unstructured/semi-structured data.

**Types:**

### Key-Value Stores

- **Structure**: Key → Value pairs
- **Examples**: Redis, DynamoDB, Riak
- **Use Cases**: Caching, session storage, user preferences

### Document Databases

- **Structure**: JSON-like documents
- **Examples**: MongoDB, CouchDB, Firestore
- **Use Cases**: Content management, user profiles, catalogs

### Graph Databases

- **Structure**: Nodes, edges, properties
- **Examples**: Neo4j, Amazon Neptune, ArangoDB
- **Use Cases**: Social networks, recommendation engines, fraud detection

### Wide Column Databases

- **Structure**: Column families
- **Examples**: Cassandra, HBase, ScyllaDB
- **Use Cases**: Time-series data, IoT, analytics

### Time-Series Databases

- **Structure**: Timestamp-indexed data
- **Examples**: InfluxDB, TimescaleDB, Prometheus
- **Use Cases**: Metrics, monitoring, IoT sensor data

### NoSQL: Advantages

```
✓ Horizontal Scalability
  - Add more servers easily
  - Linear scaling
  - Handle billions of records
  - Petabytes of data
  
  Example: Cassandra
  3 nodes → 6 nodes = 2x capacity
  (Just add servers, auto-rebalance)

✓ Flexible Schema
  - No predefined structure
  - Add fields on the fly
  - Each document can differ
  - Rapid iteration
  
  MongoDB:
  {"name": "John", "age": 30}
  {"name": "Jane", "age": 25, "email": "jane@example.com"}
  ↑ Different fields, no migration needed

✓ High Performance
  - Optimized for specific access patterns
  - No complex joins
  - Direct lookups (key-value)
  - Denormalized data
  
  Redis:
  GET user:123  → <1ms (in-memory)
  
  DynamoDB:
  Get by partition key → ~5ms

✓ High Availability
  - Built-in replication
  - Multi-region support
  - Auto-failover
  - No single point of failure
  
  Cassandra:
  Replication factor = 3
  → Data on 3 nodes
  → 2 nodes can fail, still available

✓ Cost-Effective at Scale
  - Commodity hardware
  - Cloud-native
  - Pay for what you use (DynamoDB)
  - Better resource utilization
  
  Traditional SQL: $10,000/month (beefy server)
  NoSQL cluster: $3,000/month (5 smaller servers)

✓ Better for Specific Use Cases
  - Caching (Redis)
  - Session storage (MongoDB)
  - Analytics (Cassandra)
  - Social graphs (Neo4j)
  - Real-time (Firebase)
```

### NoSQL: Disadvantages

```
✗ Limited Query Flexibility
  - No ad-hoc queries
  - Must design access patterns upfront
  - No joins (or expensive)
  - Limited aggregations
  
  MongoDB:
  Can't efficiently query:
  "Find users who ordered product X and live in city Y"
  (if not designed for it)

✗ Eventual Consistency
  - Data may be stale temporarily
  - Different nodes may disagree
  - Application must handle
  - Race conditions possible
  
  Example:
  Write to Node A: user.balance = 100
  Immediately read from Node B: user.balance = 90 (stale!)
  
  After 100ms: All nodes = 100 (eventually consistent)

✗ Limited Transaction Support
  - No multi-document ACID (usually)
  - MongoDB: Single document ACID only
  - Cassandra: No transactions
  - Application-level coordination needed
  
  Can't do:
  Transfer money from Account A to B atomically
  (across documents)

✗ Learning Curve
  - Different query languages
  - New concepts (partition keys, denormalization)
  - Access pattern design critical
  - No standard like SQL

✗ Denormalization Complexity
  - Data duplication
  - Update anomalies
  - More storage needed
  - Application must maintain consistency
  
  Example:
  User data stored in:
  - users collection
  - orders.user_info
  - posts.author
  
  Update user name → Must update 3 places!

✗ Less Mature Tooling
  - Fewer GUI tools
  - Less sophisticated ORMs
  - Debugging harder
  - Smaller talent pool

✗ Operational Complexity
  - Distributed systems are complex
  - Replication lag
  - Split-brain scenarios
  - Data consistency issues
  - Monitoring more complex
```

### When to Choose NoSQL

```
✓ High Volume, High Velocity
  - Millions of writes/sec
  - IoT sensor data
  - Log aggregation
  - Analytics events

✓ Flexible/Evolving Schema
  - Rapid development
  - Frequent schema changes
  - Heterogeneous data
  - MVP/prototyping

✓ Horizontal Scaling Needed
  - Billions of records
  - Petabytes of data
  - Geographic distribution
  - Cannot fit on one machine

✓ Specific Data Models
  - Documents: Content management
  - Key-Value: Caching, sessions
  - Graph: Social networks, recommendations
  - Wide-column: Time-series, analytics

✓ High Availability Priority
  - 99.99%+ uptime required
  - Multi-region deployment
  - Automatic failover
  - Eventual consistency acceptable
```

### NoSQL Database Comparison

**MongoDB vs Cassandra vs Redis vs Neo4j:**

| Feature | MongoDB | Cassandra | Redis | Neo4j |
|---------|---------|-----------|-------|-------|
| **Type** | Document | Wide Column | Key-Value | Graph |
| **Best For** | General purpose | Time-series, IoT | Caching, sessions | Social networks |
| **Consistency** | Strong (tunable) | Eventual (tunable) | Strong | Strong |
| **Transactions** | Multi-doc ACID | None | Limited | Full ACID |
| **Query** | Rich queries | Limited | Key lookup | Graph traversal |
| **Scaling** | Sharding | Linear | Master-replica | Sharding hard |
| **Speed** | Medium | Very fast writes | Fastest | Medium |
| **Complexity** | Low | High | Low | Medium |
| **Use Case** | Apps, CMS | Analytics, IoT | Cache, real-time | Relationships |

### Hybrid Approach: Polyglot Persistence

```
Modern architectures use multiple databases:

┌─────────────────────────────────────────┐
│          Application Layer             │
└─────────────┬────────────┬─────────────┘
              │            │            │
      ┌───────┼────────────┼────────────────┐
      │       │            │                │
      ▼       ▼            ▼                ▼
  ┌───────┐ ┌───────┐   ┌───────┐   ┌──────────┐
  │ Postgr│ │ MongoDB│   │ Redis │   │Elasticse│
  │  SQL  │ │ (NoSQL)│   │(Cache)│   │  arch   │
  └───────┘ └───────┘   └───────┘   └──────────┘
  │                              │               │
  Users,          User              Sessions,      Full-text
  Orders,     Preferences,          Rate          Search
  Inventory   Activity Logs       Limiting
  (ACID)      (Flexible)          (Fast)

Example E-commerce App:
✓ PostgreSQL: Orders, inventory (transactions critical)
✓ MongoDB: Product catalog (flexible attributes)
✓ Redis: Session store, cart (fast, temporary)
✓ Elasticsearch: Product search (full-text)
✓ Neo4j: Recommendations (graph relationships)
```

### Decision Framework: SQL vs NoSQL

**Choose SQL when:**
```
1. Data is structured and relationships are important
2. ACID transactions are critical
3. Complex queries and joins needed
4. Data integrity more important than scale
5. Team familiar with SQL
6. Vertical scaling sufficient
7. Strong consistency required

Examples:
- Banking system
- E-commerce orders/inventory
- ERP/CRM
- Booking/reservation systems
```

**Choose NoSQL when:**
```
1. Massive scale (billions of records)
2. Schema frequently changes
3. Simple access patterns (key-value lookups)
4. Horizontal scaling needed
5. Eventual consistency acceptable
6. High write throughput
7. Geographic distribution

Examples:
- Social media feeds
- IoT sensor data
- Real-time analytics
- Session storage
- Caching layer
```

**Red Flags for Each:**

```
Don't use SQL if:
✗ Need to scale to billions of records
✗ Schema changes daily
✗ Write-heavy workload (1M+ writes/sec)
✗ Multi-region with low latency required

Don't use NoSQL if:
✗ Complex multi-table joins required
✗ ACID transactions critical
✗ Team has no NoSQL experience
✗ Data fits comfortably in SQL
✗ Ad-hoc queries needed frequently
```

### SQL vs NoSQL

| Aspect | SQL | NoSQL |
|--------|-----|-------|
| Schema | Fixed | Flexible |
| Scaling | Vertical | Horizontal |
| Consistency | Strong | Eventual |
| Transactions | Full ACID | Limited |
| Queries | Complex joins | Simple lookups |
| Use Case | Banking, ERP | Social media, IoT |
