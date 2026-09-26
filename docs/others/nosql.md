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

NoSQL ("Not Only SQL") databases are non-relational data stores designed for flexible schemas, horizontal scalability, and high-performance access to unstructured or semi-structured data. They emerged in the late 2000s driven by the needs of internet-scale companies (Google BigTable, Amazon Dynamo, Facebook Cassandra) that couldn't meet their requirements with traditional RDBMS.

**Core Principles:**

- **BASE** over ACID — **B**asically **A**vailable, **S**oft state, **E**ventually consistent
- **Schema-on-read** instead of schema-on-write
- **Horizontal scaling** (scale-out) over vertical scaling (scale-up)
- **Denormalization** and data duplication over normalization and joins

```
Traditional SQL (ACID)                     NoSQL (BASE)
┌─────────────────────────┐               ┌─────────────────────────┐
│ Atomicity               │               │ Basically Available     │
│ Consistency              │               │ Soft State              │
│ Isolation                │               │ Eventually Consistent   │
│ Durability               │               │                         │
├─────────────────────────┤               ├─────────────────────────┤
│ Strong guarantees        │               │ Relaxed guarantees      │
│ Single-server optimized  │               │ Distributed-first       │
│ Normalized data          │               │ Denormalized data       │
│ Schema-on-write          │               │ Schema-on-read          │
└─────────────────────────┘               └─────────────────────────┘
```

**The CAP Theorem** — a fundamental constraint for all distributed NoSQL systems:

```
              Consistency
                 /\
                /  \
               /    \
              / CA   \
             / (RDBMS)\
            /──────────\
           /            \
          /   You can    \
         /   only pick    \
        /    TWO of       \
       /     THREE         \
      /                     \
     /  CP            AP     \
    / (MongoDB,   (Cassandra, \
   /  HBase,      DynamoDB,    \
  /   Redis)      CouchDB)      \
 /________________________________\
Availability          Partition Tolerance

CA = Consistency + Availability       → Traditional RDBMS (not partition-tolerant)
CP = Consistency + Partition Tolerance → MongoDB, HBase, Redis
AP = Availability + Partition Tolerance → Cassandra, DynamoDB, CouchDB
```

In a distributed system, network partitions **will** happen. So in practice, you choose between **CP** (reject requests during partition to stay consistent) or **AP** (serve potentially stale data to stay available).

---

**Types:**

### Key-Value Stores

- **Structure**: Key → Value pairs (value is opaque to the database)
- **Examples**: Redis, DynamoDB, Riak, Memcached, etcd
- **Use Cases**: Caching, session storage, user preferences, rate limiting, leaderboards

**How it works:**

A key-value store is the simplest NoSQL model. It functions like a giant distributed hash map. The database doesn't inspect or index the value — it only knows how to store and retrieve by the key.

```
┌──────────────────────────────────────────────────────────────┐
│                    Key-Value Store                            │
├──────────────────┬───────────────────────────────────────────┤
│       Key        │                 Value                     │
├──────────────────┼───────────────────────────────────────────┤
│ user:1001        │ {"name":"Alice","email":"alice@mail.com"} │
│ session:abc123   │ {"userId":1001,"expires":"2026-05-16"}    │
│ cart:1001        │ ["item:501","item:302","item:118"]        │
│ rate:192.168.1.1 │ 47                                       │
│ config:app:v2    │ {"maxConn":100,"timeout":30}             │
└──────────────────┴───────────────────────────────────────────┘

Operations:
  GET key          → O(1) lookup
  SET key value    → O(1) write
  DEL key          → O(1) delete
  EXPIRE key ttl   → Auto-delete after TTL
```

**Redis example — Session store & caching:**

```bash
# Store a user session with 30-minute TTL
SET session:abc123 '{"userId":1001,"role":"admin","cart":["item:501"]}' EX 1800

# Retrieve session
GET session:abc123

# Atomic counter for rate limiting
INCR rate_limit:192.168.1.1
EXPIRE rate_limit:192.168.1.1 60

# Check rate limit (allow 100 requests per minute)
GET rate_limit:192.168.1.1
# If > 100, reject the request
```

**Redis example — Leaderboard with sorted sets:**

```bash
# Add players with scores
ZADD leaderboard 1500 "player:alice"
ZADD leaderboard 2300 "player:bob"
ZADD leaderboard 1800 "player:charlie"
ZADD leaderboard 3100 "player:diana"

# Get top 3 players (highest scores first)
ZREVRANGE leaderboard 0 2 WITHSCORES
# 1) "player:diana"   → 3100
# 2) "player:bob"     → 2300
# 3) "player:charlie" → 1800

# Get rank of a specific player
ZREVRANK leaderboard "player:alice"
# 3 (0-indexed, so 4th place)
```

**DynamoDB example — User preferences (Python boto3):**

```python
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('UserPreferences')

# Write
table.put_item(Item={
    'userId': 'user:1001',
    'theme': 'dark',
    'language': 'en',
    'notifications': True
})

# Read (single-digit millisecond latency)
response = table.get_item(Key={'userId': 'user:1001'})
prefs = response['Item']
```

**Data partitioning in key-value stores:**

```
Hash(key) → Partition

Key: "user:1001"  → Hash → Partition 2 → Node B
Key: "user:1002"  → Hash → Partition 0 → Node A
Key: "user:1003"  → Hash → Partition 1 → Node C

┌──────────┐    ┌──────────┐    ┌──────────┐
│  Node A  │    │  Node B  │    │  Node C  │
│ Part 0   │    │ Part 2   │    │ Part 1   │
│user:1002 │    │user:1001 │    │user:1003 │
│  ...     │    │  ...     │    │  ...     │
└──────────┘    └──────────┘    └──────────┘

Consistent hashing ensures minimal data movement
when adding/removing nodes.
```

---

### Document Databases

- **Structure**: JSON/BSON-like documents organized in collections
- **Examples**: MongoDB, CouchDB, Firestore, Amazon DocumentDB
- **Use Cases**: Content management, user profiles, product catalogs, event logging

**How it works:**

Document databases store data as self-describing documents (usually JSON or BSON). Each document can have a different structure — fields can be added, removed, or nested without affecting other documents. The database **understands** the document structure and can index and query on any field.

```
┌───────────────────────────────────────────────────────────────────┐
│                    Collection: "products"                          │
├───────────────────────────────────────────────────────────────────┤
│ {                           │ {                                   │
│   "_id": "prod:501",       │   "_id": "prod:502",               │
│   "name": "Laptop",        │   "name": "T-Shirt",               │
│   "price": 999.99,         │   "price": 29.99,                  │
│   "specs": {               │   "sizes": ["S","M","L","XL"],     │
│     "cpu": "i7",           │   "color": "blue",                 │
│     "ram": "16GB",         │   "material": "cotton"             │
│     "storage": "512GB SSD" │ }                                   │
│   },                       │                                     │
│   "reviews": [             │ ← Different structure, same         │
│     {"user":"alice",       │   collection. No migration needed!  │
│      "rating":5}           │                                     │
│   ]                        │                                     │
│ }                          │                                     │
└───────────────────────────────────────────────────────────────────┘

Key difference from Key-Value:
  Key-Value:  DB sees value as opaque blob
  Document:   DB understands document structure → can index & query fields
```

**MongoDB example — Product catalog with nested data:**

```javascript
// Insert a product with nested specs and array of reviews
db.products.insertOne({
  name: "MacBook Pro 16",
  brand: "Apple",
  price: 2499.99,
  category: "electronics",
  specs: {
    cpu: "M3 Max",
    ram: "36GB",
    storage: "1TB SSD",
    display: "16.2-inch Liquid Retina XDR"
  },
  tags: ["laptop", "professional", "creative"],
  reviews: [
    { user: "alice", rating: 5, text: "Best laptop ever!" },
    { user: "bob", rating: 4, text: "Expensive but worth it" }
  ],
  inStock: true,
  createdAt: new Date()
});

// Query: Find all laptops under $2000 with rating >= 4
db.products.find({
  tags: "laptop",
  price: { $lt: 2000 },
  "reviews.rating": { $gte: 4 }
});

// Aggregation pipeline: Average price per category
db.products.aggregate([
  { $group: {
      _id: "$category",
      avgPrice: { $avg: "$price" },
      count: { $sum: 1 }
  }},
  { $sort: { avgPrice: -1 } }
]);

// Create indexes on frequently queried fields
db.products.createIndex({ category: 1, price: 1 });
db.products.createIndex({ tags: 1 });
db.products.createIndex({ "reviews.rating": 1 });
```

**Document embedding vs referencing — a critical design decision:**

```
Strategy 1: EMBEDDING (denormalized)              Strategy 2: REFERENCING (normalized)
─────────────────────────────────                  ─────────────────────────────────────
{                                                  // orders collection
  "_id": "order:1001",                             {
  "customer": {               ← Embedded            "_id": "order:1001",
    "name": "Alice",                                 "customerId": "cust:501",  ← Reference
    "email": "alice@mail.com"                        "items": ["prod:501", "prod:502"],
  },                                                 "total": 1029.98
  "items": [                                       }
    { "name":"Laptop",                             
      "price": 999.99 },      ← All in one        // customers collection
    { "name":"T-Shirt",          document           {
      "price": 29.99 }                               "_id": "cust:501",
  ],                                                  "name": "Alice",
  "total": 1029.98                                    "email": "alice@mail.com"
}                                                  }

When to EMBED:                                     When to REFERENCE:
✓ 1:1 or 1:few relationships                      ✓ 1:many or many:many relationships
✓ Data always accessed together                    ✓ Data accessed independently
✓ Data doesn't change often                        ✓ Data changes frequently
✓ Document stays under 16MB                        ✓ Unbounded arrays
```

---

### Graph Databases

- **Structure**: Nodes (entities), edges (relationships), properties (attributes)
- **Examples**: Neo4j, Amazon Neptune, ArangoDB, JanusGraph
- **Use Cases**: Social networks, recommendation engines, fraud detection, knowledge graphs

**How it works:**

Graph databases store data as a network of nodes connected by edges. Both nodes and edges can carry properties. The key advantage is **index-free adjacency** — each node directly references its neighbors, making relationship traversal O(1) per hop regardless of total graph size.

```
                    ┌─────────────────┐
                    │   Alice (User)  │
                    │ age: 30         │
                    │ city: "NYC"     │
                    └────┬───────┬────┘
                FRIENDS  │       │  PURCHASED
                 since:  │       │  date: "2026-01"
                 2020    │       │
        ┌────────────────┘       └──────────────────┐
        ▼                                           ▼
┌─────────────────┐                     ┌──────────────────────┐
│   Bob (User)    │                     │  MacBook (Product)   │
│ age: 28         │──── REVIEWED ──────▶│  price: 2499         │
│ city: "SF"      │     rating: 5       │  category: "laptop"  │
└────┬────────────┘                     └──────────────────────┘
     │ FRIENDS                                      ▲
     │ since: 2021                                  │
     ▼                                    PURCHASED │
┌─────────────────┐                     date: "2026-03"
│  Charlie (User) │─────────────────────────────────┘
│ age: 35         │
│ city: "NYC"     │
└─────────────────┘

SQL approach: Multiple JOINs across tables → O(n) per join
Graph approach: Pointer traversal → O(1) per hop
```

**Neo4j Cypher example — Social network queries:**

```cypher
// Create nodes and relationships
CREATE (alice:User {name: "Alice", age: 30, city: "NYC"})
CREATE (bob:User {name: "Bob", age: 28, city: "SF"})
CREATE (charlie:User {name: "Charlie", age: 35, city: "NYC"})
CREATE (macbook:Product {name: "MacBook Pro", price: 2499, category: "laptop"})

CREATE (alice)-[:FRIENDS {since: 2020}]->(bob)
CREATE (bob)-[:FRIENDS {since: 2021}]->(charlie)
CREATE (alice)-[:PURCHASED {date: "2026-01"}]->(macbook)
CREATE (charlie)-[:PURCHASED {date: "2026-03"}]->(macbook)
CREATE (bob)-[:REVIEWED {rating: 5, text: "Amazing!"}]->(macbook)

// Friend-of-friend recommendation: 
// "Find people Alice doesn't know who bought the same products"
MATCH (alice:User {name: "Alice"})-[:PURCHASED]->(product)<-[:PURCHASED]-(other)
WHERE NOT (alice)-[:FRIENDS]-(other) AND alice <> other
RETURN other.name AS recommendation, product.name AS commonProduct

// Find shortest path between two users
MATCH path = shortestPath(
  (alice:User {name: "Alice"})-[:FRIENDS*]-(charlie:User {name: "Charlie"})
)
RETURN path

// Fraud detection: Find circular money transfers
MATCH path = (a:Account)-[:TRANSFERRED*3..6]->(a)
WHERE ALL(t IN relationships(path) WHERE t.amount > 10000)
RETURN path
```

**Why graphs beat SQL for relationship queries:**

```
"Find friends of friends of friends" 

SQL (3 self-joins):
  SELECT DISTINCT f3.friend_id
  FROM friends f1
  JOIN friends f2 ON f1.friend_id = f2.user_id
  JOIN friends f3 ON f2.friend_id = f3.user_id
  WHERE f1.user_id = 'alice'
  
  Performance: O(n³) — joins explode with depth
  With 1M users: ~30 seconds

Graph (Cypher):
  MATCH (alice:User {name:"Alice"})-[:FRIENDS*3]->(fof)
  RETURN DISTINCT fof
  
  Performance: O(k³) where k = avg connections per node
  With 1M users: ~2 milliseconds
```

---

### Wide Column Databases

- **Structure**: Column families with rows, where each row can have different columns
- **Examples**: Apache Cassandra, HBase, ScyllaDB, Google Bigtable
- **Use Cases**: Time-series data, IoT, analytics, event logging, messaging

**How it works:**

Wide-column stores organize data into rows and column families, but unlike RDBMS, each row can have a different set of columns. Data is stored column-wise, making it efficient for queries that read specific columns across many rows. The **partition key** determines data distribution, and the **clustering key** determines sort order within a partition.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Table: sensor_readings                                                  │
│  Partition Key: sensor_id  |  Clustering Key: timestamp (DESC)          │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Partition: sensor_id = "temp-001"                                       │
│  ┌───────────────┬─────────────┬──────────┬──────────┬─────────────────┐│
│  │  timestamp    │ temperature │ humidity │ battery  │ location        ││
│  ├───────────────┼─────────────┼──────────┼──────────┼─────────────────┤│
│  │ 2026-05-15T10 │ 23.5        │ 65       │ 87%      │ "Building A"   ││
│  │ 2026-05-15T09 │ 22.1        │ 68       │ 87%      │ "Building A"   ││
│  │ 2026-05-15T08 │ 20.8        │ 72       │ 88%      │ "Building A"   ││
│  └───────────────┴─────────────┴──────────┴──────────┴─────────────────┘│
│                                                                          │
│  Partition: sensor_id = "temp-002"                                       │
│  ┌───────────────┬─────────────┬──────────┬──────────┐                  │
│  │  timestamp    │ temperature │ pressure │ status   │  ← Different    │
│  ├───────────────┼─────────────┼──────────┼──────────┤    columns!     │
│  │ 2026-05-15T10 │ 19.3        │ 1013.2   │ "OK"     │                  │
│  │ 2026-05-15T09 │ 18.7        │ 1013.5   │ "OK"     │                  │
│  └───────────────┴─────────────┴──────────┴──────────┘                  │
└──────────────────────────────────────────────────────────────────────────┘

Data is distributed across nodes by partition key:
  Hash("temp-001") → Node A
  Hash("temp-002") → Node C
  Hash("temp-003") → Node B
```

**Cassandra CQL example — IoT sensor data:**

```sql
-- Create keyspace with replication
CREATE KEYSPACE iot_platform
WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'datacenter1': 3,
  'datacenter2': 3
};

-- Table design: partition by sensor_id, cluster by timestamp
CREATE TABLE iot_platform.sensor_readings (
    sensor_id    TEXT,
    timestamp    TIMESTAMP,
    temperature  DOUBLE,
    humidity     DOUBLE,
    battery_pct  INT,
    location     TEXT,
    PRIMARY KEY (sensor_id, timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND default_time_to_live = 7776000;  -- 90 days TTL

-- Insert sensor reading (high write throughput)
INSERT INTO sensor_readings (sensor_id, timestamp, temperature, humidity, battery_pct, location)
VALUES ('temp-001', '2026-05-15T10:00:00Z', 23.5, 65.0, 87, 'Building A');

-- Query: Last 24 hours for a specific sensor (partition-local, very fast)
SELECT * FROM sensor_readings
WHERE sensor_id = 'temp-001'
  AND timestamp > '2026-05-14T10:00:00Z'
LIMIT 100;

-- Time-bucketed table for high-cardinality sensors
CREATE TABLE sensor_readings_bucketed (
    sensor_id    TEXT,
    date_bucket  DATE,       -- Prevents unbounded partition growth
    timestamp    TIMESTAMP,
    temperature  DOUBLE,
    PRIMARY KEY ((sensor_id, date_bucket), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC);
```

**Cassandra write path (why writes are so fast):**

```
Client Write Request
        │
        ▼
  ┌──────────┐
  │Coordinator│ (any node can coordinate)
  │   Node    │
  └─────┬─────┘
        │  Sends to replicas in parallel
        ├──────────────────┬──────────────────┐
        ▼                  ▼                  ▼
  ┌──────────┐      ┌──────────┐      ┌──────────┐
  │ Replica 1│      │ Replica 2│      │ Replica 3│
  │          │      │          │      │          │
  │ 1.Commit │      │ 1.Commit │      │ 1.Commit │
  │   Log    │      │   Log    │      │   Log    │
  │ 2.Memtable│     │ 2.Memtable│     │ 2.Memtable│
  │ 3.Ack    │      │ 3.Ack    │      │ 3.Ack    │
  └──────────┘      └──────────┘      └──────────┘
        │                  │                  │
        └───── Quorum ─────┘                  │
               (2 of 3)                       │
                  │                           
                  ▼                           
            Client gets                      
            success response                  
                                              
  Later (async): Memtable → flush → SSTable on disk
  
  Write latency: ~1-2ms (append-only, no read-before-write)
  Throughput: 100K+ writes/sec per node
```

---

### Time-Series Databases

- **Structure**: Timestamp-indexed data with tags/labels for grouping
- **Examples**: InfluxDB, TimescaleDB, Prometheus, QuestDB, Apache IoTDB
- **Use Cases**: Metrics, monitoring, IoT sensor data, financial tick data, log analytics

**How it works:**

Time-series databases are optimized for **append-heavy** workloads where data arrives chronologically and is rarely updated. They use specialized storage engines (columnar compression, time-based partitioning) that achieve 10-100x better compression than general-purpose databases.

```
┌────────────────────────────────────────────────────────────────────┐
│  Time-Series Data Model                                            │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Measurement: "cpu_usage"                                          │
│  Tags: {host: "server-01", region: "us-east", env: "prod"}       │
│  Fields: {usage_user: 45.2, usage_system: 12.1, usage_idle: 42.7}│
│  Timestamp: 2026-05-15T10:00:00Z                                  │
│                                                                    │
│  ┌──────────────────┬──────────┬───────────┬───────────┬────────┐ │
│  │    timestamp     │  host    │usage_user │usage_sys  │ idle   │ │
│  ├──────────────────┼──────────┼───────────┼───────────┼────────┤ │
│  │ 10:00:00         │server-01 │   45.2    │   12.1    │  42.7  │ │
│  │ 10:00:10         │server-01 │   47.8    │   11.5    │  40.7  │ │
│  │ 10:00:20         │server-01 │   43.1    │   13.2    │  43.7  │ │
│  │ 10:00:00         │server-02 │   62.3    │    8.4    │  29.3  │ │
│  │ 10:00:10         │server-02 │   58.9    │    9.1    │  32.0  │ │
│  └──────────────────┴──────────┴───────────┴───────────┴────────┘ │
│                                                                    │
│  Storage: columnar, delta-encoded, compressed                      │
│  Retention: auto-downsample and delete old data                   │
└────────────────────────────────────────────────────────────────────┘
```

**InfluxDB example — Server monitoring:**

```sql
-- Write data using line protocol
-- measurement,tag=value field=value timestamp
cpu_usage,host=server-01,region=us-east usage_user=45.2,usage_system=12.1 1715770800000000000
cpu_usage,host=server-01,region=us-east usage_user=47.8,usage_system=11.5 1715770810000000000
memory,host=server-01 used_pct=72.3,available_gb=22.1 1715770800000000000

-- Query: Average CPU per host over last hour (InfluxQL)
SELECT MEAN(usage_user) FROM cpu_usage
WHERE time > now() - 1h
GROUP BY host, time(5m)

-- Query using Flux language (InfluxDB 2.x)
from(bucket: "monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cpu_usage" and r.host == "server-01")
  |> aggregateWindow(every: 5m, fn: mean)
  |> yield(name: "avg_cpu")

-- Downsampling: Keep 10s resolution for 7 days, 1h averages forever
-- (configured via retention policies and continuous queries)
CREATE CONTINUOUS QUERY cq_cpu_1h ON monitoring
BEGIN
  SELECT MEAN(usage_user) AS usage_user, MEAN(usage_system) AS usage_system
  INTO monitoring.forever.cpu_usage_1h
  FROM monitoring.seven_days.cpu_usage
  GROUP BY time(1h), host
END
```

**Prometheus example — Application metrics:**

```yaml
# prometheus.yml - Scrape config
scrape_configs:
  - job_name: 'web-app'
    scrape_interval: 15s
    static_configs:
      - targets: ['app:8080']
```

```promql
# PromQL queries

# Request rate per second over last 5 minutes
rate(http_requests_total{job="web-app"}[5m])

# 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="web-app"}[5m]))

# Alert: CPU usage > 80% for 5 minutes
# (in alerting rules)
- alert: HighCPU
  expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
  for: 5m
  labels:
    severity: warning
```

**Why time-series databases are fast:**

```
General-Purpose DB                    Time-Series DB
──────────────────                    ──────────────────
Row-oriented storage                  Columnar storage
┌─────┬──────┬─────┐                 ┌─────────────────────┐
│time │ host │ cpu │                 │ time: [t1,t2,t3,t4] │ ← Delta encoding
├─────┼──────┼─────┤                 │ host: [s1,s1,s1,s1] │ ← Dictionary encoding
│ t1  │  s1  │ 45  │                 │ cpu:  [45,47,43,48]  │ ← Gorilla compression
│ t2  │  s1  │ 47  │                 └─────────────────────┘
│ t3  │  s1  │ 43  │                 
│ t4  │  s1  │ 48  │                 Compression ratio: 10-20x better
└─────┴──────┴─────┘                 Query speed: 10-100x faster for aggregations
                                     (reads only the columns needed)
```

### NoSQL: Advantages

#### ✓ Horizontal Scalability

Add more commodity servers to handle more data and traffic. Unlike vertical scaling (buying a bigger server), horizontal scaling has no upper bound.

```
Vertical Scaling (SQL)                  Horizontal Scaling (NoSQL)
                                        
  ┌──────────────┐                      ┌────┐ ┌────┐ ┌────┐ ┌────┐
  │              │                      │Node│ │Node│ │Node│ │Node│
  │  BIG SERVER  │  $$$                 │ A  │ │ B  │ │ C  │ │ D  │
  │  128GB RAM   │                      │8GB │ │8GB │ │8GB │ │8GB │
  │  64 cores    │                      └────┘ └────┘ └────┘ └────┘
  │              │                         $      $      $      $
  └──────────────┘                      
  Max: ~$50K/month                      Scale linearly by adding nodes
  Ceiling: hardware limits              No ceiling: just add more
                                        
  Cassandra example:                    
  3 nodes → 100K writes/sec            
  6 nodes → 200K writes/sec  (linear!) 
  12 nodes → 400K writes/sec            
```

**MongoDB sharding example:**

```javascript
// Enable sharding on database
sh.enableSharding("ecommerce")

// Shard the orders collection by customer_id (hashed for even distribution)
sh.shardCollection("ecommerce.orders", { customer_id: "hashed" })

// MongoDB auto-distributes data across shards:
// Shard 1: customer_id hash range [-∞, -3074457345618258602)
// Shard 2: customer_id hash range [-3074457345618258602, 0)
// Shard 3: customer_id hash range [0, 3074457345618258602)
// Shard 4: customer_id hash range [3074457345618258602, +∞)

// Check shard distribution
db.orders.getShardDistribution()
```

#### ✓ Flexible Schema

No predefined structure. Each document/record can differ. Schema evolves with your application — no ALTER TABLE, no downtime migrations.

```javascript
// MongoDB: Documents in the same collection can have different fields
// Version 1 of your app
db.users.insertOne({
  name: "Alice",
  email: "alice@mail.com"
})

// Version 2: Added phone and address — no migration needed!
db.users.insertOne({
  name: "Bob",
  email: "bob@mail.com",
  phone: "+1-555-0123",
  address: {
    street: "123 Main St",
    city: "NYC",
    zip: "10001"
  },
  preferences: {
    theme: "dark",
    notifications: true
  }
})

// Both documents coexist happily. Query either:
db.users.find({ name: "Alice" })
// Returns: { name: "Alice", email: "alice@mail.com" }
// No error for missing fields — they're simply absent

// Schema validation (optional, when you want some structure):
db.createCollection("users", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["name", "email"],
      properties: {
        name: { bsonType: "string" },
        email: { bsonType: "string", pattern: "^.+@.+$" }
      }
    }
  }
})
```

#### ✓ High Performance

Optimized for specific access patterns. No complex joins. Direct lookups. Denormalized data means fewer disk reads per query.

```
Performance Comparison (approximate):

Operation                  SQL (PostgreSQL)    NoSQL
─────────────────────────  ──────────────────  ──────────────────
Key lookup                 ~5ms                ~1ms (Redis: <0.5ms)
Insert single record       ~5ms                ~1ms (Cassandra)
Read with 3-table JOIN     ~50ms               N/A (denormalized: ~2ms)
Write 10K records/sec      Challenging          Easy (Cassandra: 100K+/sec)
Full-text search           ~100ms              ~10ms (Elasticsearch)
```

**Redis pipelining for bulk operations:**

```python
import redis

r = redis.Redis(host='localhost', port=6379)

# Without pipeline: 1000 round trips
# for i in range(1000):
#     r.set(f"key:{i}", f"value:{i}")    # ~1000ms total

# With pipeline: 1 round trip for 1000 operations
pipe = r.pipeline()
for i in range(1000):
    pipe.set(f"key:{i}", f"value:{i}")
results = pipe.execute()  # ~5ms total (200x faster)
```

#### ✓ High Availability

Built-in replication, multi-region support, automatic failover. Designed to survive node failures without human intervention.

```
Cassandra: Multi-DC Replication (RF=3 per DC)

  Data Center 1 (US-East)           Data Center 2 (EU-West)
  ┌──────┐ ┌──────┐ ┌──────┐       ┌──────┐ ┌──────┐ ┌──────┐
  │Node 1│ │Node 2│ │Node 3│       │Node 4│ │Node 5│ │Node 6│
  │  ●   │ │  ●   │ │  ●   │  ←──▶ │  ●   │ │  ●   │ │  ●   │
  │copy 1│ │copy 2│ │copy 3│ async │copy 1│ │copy 2│ │copy 3│
  └──────┘ └──────┘ └──────┘ repli └──────┘ └──────┘ └──────┘
                              cation
  Write with LOCAL_QUORUM:
  → 2 of 3 local nodes acknowledge → success
  → 3rd local node + remote DC replicate async
  
  Node 2 dies? No problem:
  → Reads/writes continue on Node 1 & 3
  → When Node 2 recovers, it catches up automatically (hinted handoff)
  
  Entire US-East DC goes down?
  → EU-West continues serving all traffic
  → Zero downtime, zero data loss
```

**MongoDB Replica Set failover:**

```javascript
// Replica set configuration
rs.initiate({
  _id: "myReplicaSet",
  members: [
    { _id: 0, host: "mongo1:27017", priority: 2 },  // Preferred primary
    { _id: 1, host: "mongo2:27017", priority: 1 },
    { _id: 2, host: "mongo3:27017", priority: 1 }
  ]
})

// Automatic failover:
// 1. Primary (mongo1) goes down
// 2. Secondaries detect failure via heartbeat (~10 seconds)
// 3. Election happens among remaining members
// 4. New primary elected (mongo2 or mongo3)
// 5. Application driver auto-reconnects to new primary
// Total downtime: ~10-30 seconds (automatic, no human needed)

// Read from nearest replica for lower latency
db.getMongo().setReadPref("nearest")
```

#### ✓ Cost-Effective at Scale

Commodity hardware instead of expensive enterprise servers. Cloud-native pricing models.

```
Scale comparison at 10TB data, 50K requests/sec:

SQL (Vertical):
  1x r6i.16xlarge (64 vCPU, 512GB RAM)     = $8,140/month
  Enterprise DB license                      = $5,000/month
  Total                                      = ~$13,140/month

NoSQL (Horizontal — Cassandra):
  6x i3.2xlarge (8 vCPU, 61GB RAM, NVMe)   = $4,380/month
  No license fee (open source)               = $0
  Total                                      = ~$4,380/month
                                              (3.3x cheaper)

DynamoDB (Serverless):
  On-demand: Pay per request
  50K reads/sec × $0.25/million              = ~$1,080/month
  10K writes/sec × $1.25/million             = ~$1,080/month
  Storage: 10TB × $0.25/GB                   = $2,500/month
  Total                                      = ~$4,660/month
  (Plus: zero ops, auto-scaling, fully managed)
```

#### ✓ Better for Specific Use Cases

Each NoSQL type is purpose-built for specific data patterns:

```
Use Case                    Best NoSQL Type         Why
────────────────────────    ──────────────────      ──────────────────────────
Caching/Sessions            Redis (Key-Value)       Sub-ms latency, TTL support
User profiles/CMS           MongoDB (Document)      Flexible nested data
Social networks             Neo4j (Graph)           Relationship traversal
IoT/Time-series             Cassandra (Wide-Col)    High write throughput
Server monitoring           InfluxDB (Time-Series)  Time-based aggregations
Full-text search            Elasticsearch           Inverted index, relevance
Real-time chat              Firebase (Document)     Real-time sync, offline
Config management           etcd (Key-Value)        Consistency, watch keys
Shopping cart               DynamoDB (Key-Value)    Predictable performance
Recommendation engine       Neo4j (Graph)           Pattern matching in graphs
```

### NoSQL: Disadvantages

#### ✗ Limited Query Flexibility

You must design your data model around **access patterns** upfront. Ad-hoc queries and complex joins are either impossible or very expensive.

```
SQL: Design schema first, query any way later
  SELECT u.name, COUNT(o.id) as total_orders, SUM(o.amount) as total_spent
  FROM users u
  JOIN orders o ON u.id = o.user_id
  WHERE u.city = 'NYC' AND o.date > '2026-01-01'
  GROUP BY u.name
  HAVING total_spent > 1000
  ORDER BY total_spent DESC
  
  ↑ Any combination of filters/joins/aggregations works

NoSQL (Cassandra): Must design tables for each query
  -- Need "orders by user"? Create a table for it:
  CREATE TABLE orders_by_user (
    user_id UUID, order_date TIMESTAMP, amount DECIMAL,
    PRIMARY KEY (user_id, order_date)
  );
  
  -- Need "orders by city"? Create ANOTHER table:
  CREATE TABLE orders_by_city (
    city TEXT, order_date TIMESTAMP, user_id UUID, amount DECIMAL,
    PRIMARY KEY (city, order_date)
  );
  
  -- Need "orders by product"? Yet ANOTHER table:
  -- Same data, 3 different tables. This is normal in Cassandra.
  
  -- ✗ Can NOT do: "Find users in NYC who spent > $1000"
  -- (unless you designed a table specifically for this query)
```

**MongoDB limitation example — $lookup (join) performance:**

```javascript
// MongoDB $lookup is much slower than SQL JOINs
// because it's not optimized for relational operations
db.orders.aggregate([
  { $lookup: {
      from: "users",
      localField: "userId",
      foreignField: "_id",
      as: "user"
  }},
  { $unwind: "$user" },
  { $match: { "user.city": "NYC" } },
  { $group: {
      _id: "$user.name",
      totalSpent: { $sum: "$amount" }
  }}
])
// This works but is 10-50x slower than equivalent SQL JOIN
// because MongoDB must scan the users collection for each order

// Better approach: Denormalize — embed city in orders
db.orders.insertOne({
  userId: "user:1001",
  userCity: "NYC",        // ← Duplicated from users collection
  userName: "Alice",      // ← Duplicated from users collection
  amount: 150.00,
  items: [...]
})
// Now the query is fast (single collection scan), but you
// must update all orders if user moves to a new city
```

#### ✗ Eventual Consistency

In distributed NoSQL systems, replicas may temporarily disagree. Reads might return stale data.

```
Timeline of an eventually consistent write:

T=0ms    Client writes: user.balance = 100 → Node A (primary)
T=1ms    Node A acknowledges write to client ✓
T=2ms    Node A starts replicating to Node B (async)
T=3ms    Client reads from Node B → Gets balance = 90 (STALE!) ✗
T=5ms    Node B receives replica → Updates to balance = 100
T=6ms    Client reads from Node B → Gets balance = 100 ✓

         Node A                    Node B                   Node C
         ┌──────┐                  ┌──────┐                 ┌──────┐
T=0ms    │ 100  │                  │  90  │                 │  90  │
T=1ms    │ 100  │─── replicating──▶│  90  │──replicating──▶│  90  │
T=5ms    │ 100  │                  │ 100  │                 │  90  │
T=8ms    │ 100  │                  │ 100  │                 │ 100  │
         └──────┘                  └──────┘                 └──────┘
                                          ↑
                              Inconsistency window: 3-8ms
```

**Real-world consequence — Shopping cart race condition:**

```python
# Two concurrent requests for the same user's cart

# Request A (Add laptop)                # Request B (Add mouse)
cart = get_cart("user:1001")             cart = get_cart("user:1001")  
# cart = ["keyboard"]                    # cart = ["keyboard"] (same stale read!)
cart.append("laptop")                    cart.append("mouse")
save_cart("user:1001", cart)             save_cart("user:1001", cart)
# cart = ["keyboard", "laptop"]          # cart = ["keyboard", "mouse"]
                                         # ✗ LAPTOP IS LOST!

# Fix: Use atomic operations instead of read-modify-write
# MongoDB:
db.carts.updateOne(
    { userId: "user:1001" },
    { $push: { items: "laptop" } }    # Atomic array append — no race condition
)
```

**Tunable consistency (Cassandra):**

```sql
-- Write to ALL replicas (strong consistency, but slow)
CONSISTENCY ALL;
INSERT INTO users (id, balance) VALUES ('user:1001', 100);

-- Write to QUORUM (majority — balances speed vs consistency)
CONSISTENCY QUORUM;
INSERT INTO users (id, balance) VALUES ('user:1001', 100);
-- If RF=3: writes to 2 of 3 nodes before acknowledging

-- Read with QUORUM + Write with QUORUM = strong consistency
-- Formula: R + W > N (where N = replication factor)
-- QUORUM read (2) + QUORUM write (2) > RF (3) → consistent!
```

#### ✗ Limited Transaction Support

Most NoSQL databases don't support multi-document/multi-row ACID transactions. This means complex business operations that require atomicity across multiple records need application-level workarounds.

```
SQL: Simple bank transfer (ACID guaranteed)
  BEGIN TRANSACTION;
    UPDATE accounts SET balance = balance - 100 WHERE id = 'alice';
    UPDATE accounts SET balance = balance + 100 WHERE id = 'bob';
    INSERT INTO transactions (from, to, amount) VALUES ('alice', 'bob', 100);
  COMMIT;
  -- All 3 operations succeed or all fail. Always.

Cassandra: No multi-row transactions at all
  -- Must use application-level saga pattern:
  -- 1. Write "pending" transaction record
  -- 2. Debit Alice's account  
  -- 3. Credit Bob's account
  -- 4. Mark transaction "complete"
  -- If step 3 fails, application must detect and rollback step 2
  -- This is complex, error-prone, and hard to get right
```

**MongoDB (v4.0+) multi-document transactions:**

```javascript
// MongoDB added multi-document ACID in v4.0 — but with caveats
const session = db.getMongo().startSession();
session.startTransaction({
  readConcern: { level: "snapshot" },
  writeConcern: { w: "majority" }
});

try {
  const accounts = session.getDatabase("bank").accounts;
  const txnLog = session.getDatabase("bank").transactions;
  
  // Debit Alice
  accounts.updateOne(
    { _id: "alice", balance: { $gte: 100 } },  // Ensure sufficient funds
    { $inc: { balance: -100 } },
    { session }
  );
  
  // Credit Bob
  accounts.updateOne(
    { _id: "bob" },
    { $inc: { balance: 100 } },
    { session }
  );
  
  // Log transaction
  txnLog.insertOne(
    { from: "alice", to: "bob", amount: 100, date: new Date() },
    { session }
  );
  
  session.commitTransaction();
} catch (error) {
  session.abortTransaction();  // All changes rolled back
} finally {
  session.endSession();
}

// ⚠️ Caveats:
// - Transactions across shards are slower (~2-5x overhead)
// - 60-second default timeout
// - Not designed for high-throughput transactional workloads
// - If you need lots of transactions, SQL is probably better
```

#### ✗ Learning Curve

Each NoSQL database has its own query language, data modeling philosophy, and operational patterns. There's no universal standard like SQL.

```
Same task — "Find users older than 25" — in different databases:

SQL:        SELECT * FROM users WHERE age > 25;

MongoDB:    db.users.find({ age: { $gt: 25 } })

Cassandra:  SELECT * FROM users WHERE age > 25 ALLOW FILTERING;
            -- ⚠️ ALLOW FILTERING = full table scan = BAD!
            -- Cassandra requires queries on partition/clustering keys

DynamoDB:   table.scan(
              FilterExpression=Attr('age').gt(25)
            )
            -- ⚠️ Scan = reads entire table = expensive!
            -- Must design GSI (Global Secondary Index) for this

Neo4j:      MATCH (u:User) WHERE u.age > 25 RETURN u

Redis:      -- Not directly possible! Key-value only.
            -- Must maintain a sorted set: ZRANGEBYSCORE users:by_age 25 +inf
            -- Or use RediSearch module: FT.SEARCH idx:users "@age:[25 +inf]"
```

#### ✗ Denormalization Complexity

NoSQL favors denormalized data (duplicating data across collections/tables). This improves read performance but creates update anomalies — changing one piece of data may require updating it in many places.

```
Denormalized E-commerce Data:

┌──────────────────────┐     ┌──────────────────────┐
│  users collection    │     │  orders collection   │
├──────────────────────┤     ├──────────────────────┤
│ {                    │     │ {                    │
│   _id: "user:1001", │     │   _id: "order:5001", │
│   name: "Alice",    │ ──▶ │   userName: "Alice", │ ← Duplicate!
│   email: "a@b.com", │     │   userEmail: "a@b.com│ ← Duplicate!
│   city: "NYC"       │     │   items: [...]       │
│ }                    │     │ }                    │
└──────────────────────┘     └──────────────────────┘
                                        │
                              ┌─────────┘
                              ▼
                    ┌──────────────────────┐
                    │  reviews collection  │
                    ├──────────────────────┤
                    │ {                    │
                    │   _id: "rev:9001",   │
                    │   authorName: "Alice"│ ← Duplicate!
                    │   authorCity: "NYC", │ ← Duplicate!
                    │   rating: 5          │
                    │ }                    │
                    └──────────────────────┘

Alice changes her name to "Alicia":
  → Must update: users, orders, reviews, posts, comments...
  → If any update fails: data is inconsistent across collections
  → No foreign key constraints to catch this!
```

```javascript
// MongoDB: Multi-collection update (error-prone without transactions)
// Must update ALL places where user data is duplicated
const userId = "user:1001";
const newName = "Alicia";

// 1. Update user document
db.users.updateOne({ _id: userId }, { $set: { name: newName } });

// 2. Update all orders with embedded user info
db.orders.updateMany({ userId: userId }, { $set: { userName: newName } });

// 3. Update all reviews
db.reviews.updateMany({ authorId: userId }, { $set: { authorName: newName } });

// 4. Update all posts
db.posts.updateMany({ authorId: userId }, { $set: { authorName: newName } });

// ⚠️ If step 3 fails but 1 & 2 succeed → inconsistent data!
// Solution: Use transactions (slower) or accept eventual consistency
```

#### ✗ Operational Complexity

Distributed systems are inherently complex. Replication lag, split-brain scenarios, data consistency, and monitoring require specialized expertise.

```
Things that can go wrong in a distributed NoSQL cluster:

1. SPLIT BRAIN
   ┌──────────────┐    NETWORK    ┌──────────────┐
   │  DC East     │    PARTITION  │  DC West     │
   │  ┌────────┐  │  ──── ✗ ──── │  ┌────────┐  │
   │  │Primary │  │              │  │Replica │  │
   │  │Node A  │  │              │  │Node B  │  │
   │  └────────┘  │              │  └────────┘  │
   │  "I'm the    │              │  "Primary is │
   │   primary!"  │              │   dead, I'm  │
   │              │              │   primary!"  │
   └──────────────┘              └──────────────┘
   Both accept writes → Conflicting data!
   Resolution: Quorum-based election, vector clocks, LWW

2. REPLICATION LAG
   Primary: Write at T=0 ──(5 second lag)──▶ Replica
   User writes, then reads from replica → sees old data
   
3. HOTSPOTS
   Bad partition key → all traffic to one node:
   Partition key = "country"
   US: 80% of traffic → Node A overloaded
   EU: 15% of traffic → Node B idle
   Other: 5% of traffic → Node C idle

4. TOMBSTONE ACCUMULATION (Cassandra)
   Deletes create tombstones (soft-delete markers)
   Too many tombstones → slow reads, OOM errors
   Must run compaction and configure gc_grace_seconds
```

### When to Choose NoSQL

#### ✓ High Volume, High Velocity

When your workload involves millions of writes per second, NoSQL databases built on LSM-trees and append-only architectures handle this natively.

```
Write-Heavy Workload Examples:

IoT Platform:
  10,000 sensors × 1 reading/sec = 10K writes/sec
  Scale to 1M sensors = 1M writes/sec
  → Cassandra or ScyllaDB (append-only, no read-before-write)

Log Aggregation:
  500 servers × 100 log lines/sec = 50K writes/sec
  → Elasticsearch (inverted index for search)

Analytics Events:
  1M daily active users × 50 events/user/day = 50M events/day
  → ClickHouse, Cassandra, or DynamoDB

Social Media:
  Twitter: ~500K tweets/min at peak
  → Custom distributed key-value stores
```

#### ✓ Flexible/Evolving Schema

When your data structure changes frequently or varies across records.

```javascript
// E-commerce product catalog — each category has different attributes
// This is PAINFUL in SQL (EAV pattern or many nullable columns)
// but NATURAL in MongoDB:

db.products.insertMany([
  {
    type: "laptop",
    name: "MacBook Pro",
    cpu: "M3 Max", ram: "36GB", screenSize: 16.2,
    ports: ["USB-C", "HDMI", "MagSafe"]
  },
  {
    type: "shirt",
    name: "Cotton T-Shirt",
    size: "L", color: "blue", material: "100% cotton",
    washable: true
  },
  {
    type: "book",
    name: "Designing Data-Intensive Applications",
    author: "Martin Kleppmann", isbn: "978-1449373320",
    pages: 616, publisher: "O'Reilly"
  }
])
// Each product has completely different fields — no problem!
```

#### ✓ Horizontal Scaling Needed

When your data exceeds what a single server can hold or serve.

```
Data Growth Decision Tree:

Current data: 100GB, 1K req/sec
  → SQL is fine. Don't over-engineer.

Growing to: 1TB, 10K req/sec
  → SQL with read replicas still works.
  → Consider NoSQL if writes are the bottleneck.

Growing to: 10TB, 100K req/sec
  → SQL vertical scaling hits limits (~$50K/month for big box).
  → NoSQL horizontal scaling becomes cost-effective.

Growing to: 100TB+, 1M+ req/sec
  → SQL can't do this without complex sharding hacks.
  → NoSQL is designed for exactly this.
     Cassandra: Linear scaling, add nodes as needed
     DynamoDB: Auto-scales transparently
```

#### ✓ Specific Data Models

When your data naturally fits a non-relational model.

```
Document:  Content with varying attributes
           ┌─ Blog posts with different media types
           ├─ Product catalogs with varying specs
           └─ User profiles with optional fields

Key-Value: Simple lookups by identifier
           ┌─ Session tokens → user data
           ├─ Cache keys → computed results
           └─ Feature flags → on/off

Graph:     Highly connected data with complex traversals
           ┌─ Social network (friends of friends of friends)
           ├─ Fraud detection (ring patterns in transactions)
           └─ Knowledge graph (entity relationships)

Wide-Col:  Time-ordered data with known access patterns
           ┌─ Sensor readings by device by time
           ├─ User activity feeds
           └─ Message history by conversation

TimeSeries: Metrics, monitoring, financial data
           ┌─ Server CPU/memory/disk metrics
           ├─ Stock prices and trade volumes
           └─ Application request latency histograms
```

#### ✓ High Availability Priority

When downtime costs more than occasional stale reads.

```
Availability Levels:

99.9% (three nines):   8.76 hours downtime/year   → SQL with failover
99.99% (four nines):   52.6 minutes downtime/year  → NoSQL multi-node
99.999% (five nines):  5.26 minutes downtime/year  → NoSQL multi-region

Cassandra can achieve 99.999% availability:
  - No single point of failure (peer-to-peer, no master)
  - Multi-DC replication with tunable consistency
  - Survives entire datacenter outage
  - Rolling upgrades with zero downtime

DynamoDB SLA: 99.999% for Global Tables
  - Automatic multi-region replication
  - Conflict resolution via last-writer-wins
  - AWS manages everything
```

### NoSQL Database Comparison

**MongoDB vs Cassandra vs Redis vs Neo4j vs DynamoDB vs Elasticsearch:**

| Feature | MongoDB | Cassandra | Redis | Neo4j | DynamoDB | Elasticsearch |
|---------|---------|-----------|-------|-------|----------|---------------|
| **Type** | Document | Wide Column | Key-Value | Graph | Key-Value/Document | Search Engine |
| **Best For** | General purpose | Time-series, IoT | Caching, sessions | Social networks | Serverless apps | Full-text search |
| **Data Model** | JSON/BSON docs | Row + column families | Key → value | Nodes + edges | Items (key-value) | JSON documents |
| **Consistency** | Strong (tunable) | Eventual (tunable) | Strong | Strong | Strong or eventual | Near real-time |
| **Transactions** | Multi-doc ACID | Lightweight txn | MULTI/EXEC | Full ACID | Single-item ACID | None |
| **Query Language** | MQL (JSON-based) | CQL (SQL-like) | Commands | Cypher | PartiQL / API | Query DSL |
| **Scaling** | Sharding | Linear (peer-to-peer) | Master-replica | Sharding (hard) | Auto (managed) | Sharding |
| **Write Speed** | Medium | Very fast | Fastest (in-memory) | Medium | Fast | Medium |
| **Read Speed** | Fast | Fast (by partition) | Fastest | Fast (traversal) | Single-digit ms | Fast (search) |
| **Complexity** | Low | High | Low | Medium | Low (managed) | Medium |
| **Hosting** | Self/Atlas | Self/Astra | Self/Cloud | Self/Aura | AWS only | Self/Cloud |
| **License** | SSPL | Apache 2.0 | BSD/SSPL | GPL/Commercial | Proprietary | SSPL |

**Choosing by access pattern:**

```
Access Pattern                          Best Choice
─────────────────────────────────────   ───────────────────
GET/SET by key                          Redis, DynamoDB
Rich queries on nested documents        MongoDB
Time-range queries on partitioned data  Cassandra, TimescaleDB
Graph traversals (N hops)               Neo4j, Neptune
Full-text search with relevance         Elasticsearch
Aggregations on time-series             InfluxDB, ClickHouse
Sorted leaderboards                     Redis (Sorted Sets)
Geospatial queries                      MongoDB, Elasticsearch
Real-time pub/sub                       Redis, Firebase
```

### Hybrid Approach: Polyglot Persistence

Modern applications use multiple databases, each handling what it does best. This is called **polyglot persistence**.

```
                        ┌────────────────────────────┐
                        │     Application Layer      │
                        │    (API / Microservices)    │
                        └─────┬───┬───┬───┬───┬──────┘
                              │   │   │   │   │
              ┌───────────────┘   │   │   │   └───────────────┐
              │           ┌───────┘   │   └───────┐           │
              ▼           ▼           ▼           ▼           ▼
        ┌──────────┐ ┌──────────┐ ┌───────┐ ┌──────────┐ ┌───────┐
        │PostgreSQL│ │ MongoDB  │ │ Redis │ │Elastic-  │ │ Neo4j │
        │          │ │          │ │       │ │ search   │ │       │
        └──────────┘ └──────────┘ └───────┘ └──────────┘ └───────┘
             │            │           │           │           │
          Orders,      Product     Sessions,   Product    Recommend-
          Payments,    Catalog,    Cart,       Search,    ations,
          Inventory    User        Rate        Logs,      Fraud
          (ACID)       Profiles    Limiting    Analytics  Detection
                       (Flexible)  (Fast)     (Search)   (Graph)
```

**Real-world e-commerce example (Node.js):**

```javascript
// Each database handles what it's best at

const { MongoClient } = require('mongodb');
const Redis = require('ioredis');
const { Client: ElasticClient } = require('@elastic/elasticsearch');
const { Pool } = require('pg');

// PostgreSQL: Orders and payments (ACID transactions)
const pg = new Pool({ connectionString: process.env.PG_URL });

async function createOrder(userId, items, paymentInfo) {
  const client = await pg.connect();
  try {
    await client.query('BEGIN');
    const order = await client.query(
      'INSERT INTO orders (user_id, total) VALUES ($1, $2) RETURNING id',
      [userId, calculateTotal(items)]
    );
    await client.query(
      'UPDATE inventory SET quantity = quantity - $1 WHERE product_id = $2',
      [item.qty, item.productId]
    );
    await client.query(
      'INSERT INTO payments (order_id, amount, status) VALUES ($1, $2, $3)',
      [order.rows[0].id, calculateTotal(items), 'completed']
    );
    await client.query('COMMIT');
    return order.rows[0];
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  }
}

// MongoDB: Product catalog (flexible attributes per category)
const mongo = new MongoClient(process.env.MONGO_URL);
const products = mongo.db('shop').collection('products');

async function getProduct(productId) {
  return products.findOne({ _id: productId });
}

// Redis: Session & cart (sub-millisecond, auto-expire)
const redis = new Redis(process.env.REDIS_URL);

async function getCart(userId) {
  const cart = await redis.get(`cart:${userId}`);
  return cart ? JSON.parse(cart) : [];
}

async function addToCart(userId, item) {
  const cart = await getCart(userId);
  cart.push(item);
  await redis.set(`cart:${userId}`, JSON.stringify(cart), 'EX', 86400); // 24h TTL
}

// Elasticsearch: Product search (full-text, facets, relevance)
const elastic = new ElasticClient({ node: process.env.ES_URL });

async function searchProducts(query, filters) {
  return elastic.search({
    index: 'products',
    body: {
      query: {
        bool: {
          must: [{ multi_match: { query, fields: ['name^3', 'description', 'tags'] } }],
          filter: [
            filters.category && { term: { category: filters.category } },
            filters.maxPrice && { range: { price: { lte: filters.maxPrice } } }
          ].filter(Boolean)
        }
      },
      aggs: {
        categories: { terms: { field: 'category' } },
        price_ranges: { range: { field: 'price', ranges: [
          { to: 50 }, { from: 50, to: 200 }, { from: 200 }
        ]}}
      }
    }
  });
}
```

**Data synchronization between databases:**

```
How to keep multiple databases in sync:

Option 1: Dual Writes (simple but risky)
  App writes to PostgreSQL AND MongoDB
  ⚠️ If one fails, data is inconsistent

Option 2: Change Data Capture (CDC) — Recommended
  ┌──────────┐    CDC (Debezium)    ┌──────────┐
  │PostgreSQL│ ──── WAL stream ────▶│  Kafka   │
  └──────────┘                      └────┬─────┘
                                         │
                    ┌────────────────┬────┴───────────┐
                    ▼                ▼                ▼
               ┌──────────┐   ┌──────────┐   ┌──────────┐
               │ MongoDB  │   │  Redis   │   │Elastic-  │
               │ (sync)   │   │ (cache)  │   │ search   │
               └──────────┘   └──────────┘   └──────────┘
  
  PostgreSQL is the source of truth
  Kafka streams changes to all other databases
  Eventually consistent but reliable

Option 3: Event Sourcing
  All changes stored as immutable events in event store
  Each database builds its own view from events
```

### Decision Framework: SQL vs NoSQL

Use this flowchart to decide:

```
                          START
                            │
                            ▼
                 ┌─────────────────────┐
                 │ Do you need ACID    │
                 │ transactions across │────── YES ────▶ SQL (PostgreSQL, MySQL)
                 │ multiple tables?    │
                 └─────────┬───────────┘
                           │ NO
                           ▼
                 ┌─────────────────────┐
                 │ Is your schema      │
                 │ well-defined and    │────── YES ────▶ SQL (unless scale is huge)
                 │ unlikely to change? │
                 └─────────┬───────────┘
                           │ NO
                           ▼
                 ┌─────────────────────┐
                 │ Do you need complex │
                 │ JOINs and ad-hoc   │────── YES ────▶ SQL
                 │ queries?            │
                 └─────────┬───────────┘
                           │ NO
                           ▼
                 ┌─────────────────────┐
                 │ Data > 10TB or     │
                 │ > 100K req/sec?    │────── YES ────▶ NoSQL
                 └─────────┬───────────┘
                           │ NO
                           ▼
                 ┌─────────────────────┐
                 │ What's your data    │
                 │ model?              │
                 └─────────┬───────────┘
                           │
            ┌──────────────┼──────────────┬──────────────┐
            ▼              ▼              ▼              ▼
      Key-Value      Documents      Graph         Time-Series
      Redis,         MongoDB,       Neo4j,        InfluxDB,
      DynamoDB       CouchDB        Neptune       TimescaleDB
```

**Choose SQL when:**

```
1. Data is structured and relationships are important
   → Foreign keys, referential integrity, normalized schema
   → Example: Users → Orders → Order_Items → Products

2. ACID transactions are critical
   → Banking: Transfer $100 from Alice to Bob
   → Booking: Reserve seat + charge credit card atomically
   → Inventory: Decrement stock + create order atomically

3. Complex queries and joins needed
   → "Show me top 10 customers by revenue who ordered electronics 
      in Q1 from the West region, with their average order size"
   → SQL handles this in one query; NoSQL would need multiple queries

4. Data integrity more important than scale
   → Healthcare records, financial ledgers, legal documents
   → Every record must be correct, constraints enforced by DB

5. Team familiar with SQL
   → 50+ years of SQL ecosystem, tooling, talent pool
   → 90% of backend developers know SQL

6. Vertical scaling sufficient
   → Data < 5TB, requests < 50K/sec
   → A single PostgreSQL instance can handle a LOT

7. Strong consistency required
   → After a write, all subsequent reads must see that write
   → No "I just changed my password but can't log in" scenarios
```

**Choose NoSQL when:**

```
1. Massive scale (billions of records)
   → Can't fit on one server, need to distribute
   → Example: Uber — 100M+ trips, real-time location tracking

2. Schema frequently changes
   → Startup MVPs, A/B testing different data structures
   → Adding/removing fields without ALTER TABLE + migration

3. Simple access patterns (key-value lookups)
   → "Get user by ID", "Get session by token"
   → Don't need JOINs, don't need ad-hoc queries

4. Horizontal scaling needed
   → Write-heavy workloads (IoT: millions of writes/sec)
   → Geographic distribution (data centers on every continent)

5. Eventual consistency acceptable
   → Social media: "Like count off by 1 for 5 seconds" is fine
   → Analytics: "Dashboard shows data from 30 seconds ago" is fine
   → NOT fine for: bank balances, inventory counts, seat bookings

6. High write throughput
   → Cassandra: 100K+ writes/sec per node
   → DynamoDB: auto-scales to millions of writes/sec
   → PostgreSQL: ~10K writes/sec on commodity hardware

7. Geographic distribution
   → Users worldwide need low-latency access
   → Data replicated across US, EU, APAC
   → Cassandra and DynamoDB Global Tables excel here
```

**Red Flags for Each:**

```
Don't use SQL if:                           Don't use NoSQL if:
─────────────────                           ──────────────────
✗ Need to scale past 10TB                  ✗ Complex multi-table JOINs required
  without massive ops effort                  (reports, analytics dashboards)

✗ Schema changes weekly                    ✗ ACID transactions across entities
  (ALTER TABLE on 1B rows = hours)            (financial systems, bookings)

✗ Write-heavy workload                     ✗ Team has zero NoSQL experience
  (1M+ writes/sec)                            (learning curve is real)

✗ Multi-region with                        ✗ Data fits comfortably in SQL
  sub-10ms latency                            (don't add complexity for no reason)

✗ Simple key-value access                  ✗ Ad-hoc queries needed frequently
  only (SQL is overkill)                      (analysts exploring data freely)

✗ Need built-in multi-DC                   ✗ Strong consistency is non-negotiable
  with zero-downtime failover                 (money, healthcare, legal)
```

### SQL vs NoSQL — Complete Comparison

| Aspect | SQL (Relational) | NoSQL (Non-Relational) |
|--------|------------------|------------------------|
| **Schema** | Fixed, predefined (DDL) | Flexible, schema-on-read |
| **Scaling** | Vertical (scale-up) | Horizontal (scale-out) |
| **Consistency** | Strong (ACID) | Eventual or tunable (BASE) |
| **Transactions** | Full multi-table ACID | Limited (single-doc or none) |
| **Queries** | Complex JOINs, subqueries, aggregations | Simple lookups, limited JOINs |
| **Data Model** | Tables with rows and columns | Documents, key-value, graph, columns |
| **Relationships** | Foreign keys, JOINs | Embedded/denormalized or app-level |
| **Normalization** | Normalized (3NF) | Denormalized (data duplication) |
| **Writes** | Moderate (~10K/sec) | Very high (~100K+/sec) |
| **Reads** | Fast with indexes | Fast for designed access patterns |
| **Schema Migration** | ALTER TABLE (can be slow) | No migration needed |
| **Tooling** | Mature (50+ years) | Growing but less mature |
| **Talent Pool** | Very large | Smaller, specialized |
| **Cost at Scale** | Expensive (big servers) | Cost-effective (commodity hardware) |
| **Best For** | Banking, ERP, CRM, e-commerce | Social media, IoT, caching, analytics |
| **Examples** | PostgreSQL, MySQL, Oracle, SQL Server | MongoDB, Cassandra, Redis, Neo4j |

### Real-World NoSQL Architecture: Twitter-like System

```
                     ┌─────────────┐
                     │   Client    │
                     │ (Mobile/Web)│
                     └──────┬──────┘
                            │
                     ┌──────▼──────┐
                     │  API Gateway │
                     │  (Rate limit │
                     │   via Redis) │
                     └──────┬──────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
    ┌────▼─────┐      ┌────▼─────┐      ┌────▼─────┐
    │  Tweet   │      │  User    │      │  Search  │
    │ Service  │      │ Service  │      │ Service  │
    └────┬─────┘      └────┬─────┘      └────┬─────┘
         │                 │                  │
    ┌────▼─────┐      ┌────▼─────┐      ┌────▼──────┐
    │Cassandra │      │PostgreSQL│      │Elastic-   │
    │(Tweets & │      │(Accounts,│      │search     │
    │ Timelines│      │ Auth,    │      │(Tweet     │
    │ 100K+    │      │ Billing) │      │ search,   │
    │ writes/s)│      │          │      │ trending) │
    └──────────┘      └──────────┘      └───────────┘
         │
    ┌────▼─────┐      ┌──────────┐      ┌───────────┐
    │  Redis   │      │  Neo4j   │      │  Kafka    │
    │(Timeline │      │(Social   │      │(Event     │
    │ cache,   │      │ graph,   │      │ stream,   │
    │ sessions,│      │ who to   │      │ fan-out,  │
    │ counters)│      │ follow)  │      │ analytics)│
    └──────────┘      └──────────┘      └───────────┘

Each database handles its strength:
  Cassandra: High-throughput tweet storage & timeline reads
  PostgreSQL: User accounts with ACID (password changes, billing)
  Redis: Sub-ms timeline cache, rate limiting, real-time counters
  Neo4j: "Who to follow" recommendations via graph traversal
  Elasticsearch: Tweet search, hashtag trends, full-text
  Kafka: Event streaming — fan-out tweets to follower timelines
```
