# Database Sharding

## Youtube

- [What is Database Sharding?](https://www.youtube.com/watch?v=hdxdhCpgYo8)
- [When should you shard your database?](https://www.youtube.com/watch?v=iHNovZUZM3A)


## Medium

- [Understanding Database Partitioning in Distributed Systems : Rebalancing Partitions](https://medium.com/the-developers-diary/understanding-database-partitioning-in-distributed-systems-rebalancing-partitions-fa7fee542fd3)



## Theory

### What is Sharding?

**Database sharding** (also called **horizontal partitioning**) is the practice of splitting a single large dataset across multiple independent database instances (shards), where each shard holds a subset of the total rows. Each shard is a fully functional database that can be hosted on a separate server.

**Analogy**: Imagine a library with 10 million books. Instead of one giant building, you split books across 10 branch libraries — Fiction (A-F) in Branch 1, Fiction (G-M) in Branch 2, etc. Each branch independently serves its portion.

```
BEFORE Sharding (Single Database):
┌──────────────────────────────────────────────┐
│              Single Database                 │
│         100 million user rows                │
│                                              │
│  CPU: 95%  |  Disk: 2TB (filling up)        │
│  Queries: 500ms avg  |  Writes: bottleneck  │
│                                              │
│  ❌ Can't add more RAM (maxed at 512GB)     │
│  ❌ Writes can't scale (single primary)     │
│  ❌ Table scans take minutes                │
└──────────────────────────────────────────────┘

AFTER Sharding (4 Shards):
┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│   Shard 0      │  │   Shard 1      │  │   Shard 2      │  │   Shard 3      │
│  Users 0-25M   │  │  Users 25M-50M │  │  Users 50M-75M │  │  Users 75M-100M│
│                │  │                │  │                │  │                │
│  CPU: 30%      │  │  CPU: 28%      │  │  CPU: 32%      │  │  CPU: 25%      │
│  Disk: 500GB   │  │  Disk: 500GB   │  │  Disk: 500GB   │  │  Disk: 500GB   │
│  Queries: 50ms │  │  Queries: 45ms │  │  Queries: 55ms │  │  Queries: 40ms │
└────────────────┘  └────────────────┘  └────────────────┘  └────────────────┘
   ✅ Each shard has 25% of data → 10x faster queries
   ✅ Each shard on separate server → parallel writes
   ✅ Add more shards as data grows → horizontal scaling
```

### Sharding vs Partitioning

These terms are often confused. Here's the distinction:

```
PARTITIONING (single server):
┌──────────────────────────────────────────────────┐
│               Single Database Server             │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐   │
│  │ Partition 1│ │ Partition 2│ │ Partition 3│   │
│  │ Jan-Apr    │ │ May-Aug    │ │ Sep-Dec    │   │
│  └────────────┘ └────────────┘ └────────────┘   │
│  Same server, same engine, different storage     │
│  ✅ Partition pruning (only scan relevant part)  │
│  ❌ Still limited by single server resources     │
└──────────────────────────────────────────────────┘

SHARDING (multiple servers):
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│   Server 1     │  │   Server 2     │  │   Server 3     │
│  ┌──────────┐  │  │  ┌──────────┐  │  │  ┌──────────┐  │
│  │ Shard 1  │  │  │  │ Shard 2  │  │  │  │ Shard 3  │  │
│  │ Jan-Apr  │  │  │  │ May-Aug  │  │  │  │ Sep-Dec  │  │
│  └──────────┘  │  │  └──────────┘  │  │  └──────────┘  │
│  Own CPU, RAM  │  │  Own CPU, RAM  │  │  Own CPU, RAM  │
└────────────────┘  └────────────────┘  └────────────────┘
  ✅ Independent resources per shard
  ✅ True horizontal scaling
```

| Aspect | Partitioning | Sharding |
|--------|-------------|---------|
| **Servers** | Single server | Multiple servers |
| **Resources** | Shared CPU, RAM, disk | Independent per shard |
| **Scaling** | Vertical only | Horizontal |
| **JOINs** | Normal (same engine) | Cross-shard JOINs (expensive) |
| **Transactions** | Normal ACID | Distributed transactions needed |
| **Complexity** | Low (built into DB) | High (application/middleware) |

---

### Sharding Strategies

#### 1. Range-Based Sharding

Data is split into shards based on value ranges of the shard key.

```
Shard Key: user_id (integer)

┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│   Shard 0      │  │   Shard 1      │  │   Shard 2      │
│  user_id:      │  │  user_id:      │  │  user_id:      │
│  1 - 1,000,000 │  │  1M - 2,000,000│  │  2M - 3,000,000│
└────────────────┘  └────────────────┘  └────────────────┘

Query: SELECT * FROM users WHERE user_id = 1,500,000
  → Router knows: 1M < 1.5M < 2M → goes to Shard 1

Range queries are efficient:
  SELECT * FROM users WHERE user_id BETWEEN 500,000 AND 600,000
  → All data on Shard 0 → single shard query ✅
```

**PostgreSQL — Range Partitioning:**

```sql
-- Create partitioned table
CREATE TABLE orders (
    id          BIGSERIAL,
    user_id     INT NOT NULL,
    order_date  DATE NOT NULL,
    amount      DECIMAL(10,2),
    status      VARCHAR(20)
) PARTITION BY RANGE (order_date);

-- Create partitions by date range
CREATE TABLE orders_2024_q1 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE orders_2024_q2 PARTITION OF orders
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

CREATE TABLE orders_2024_q3 PARTITION OF orders
    FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');

CREATE TABLE orders_2024_q4 PARTITION OF orders
    FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');

-- Query only scans relevant partition (partition pruning)
EXPLAIN SELECT * FROM orders WHERE order_date = '2024-05-15';
-- → Scans only orders_2024_q2, skips all other partitions
```

**MySQL — Range Partitioning:**

```sql
CREATE TABLE orders (
    id          BIGINT AUTO_INCREMENT,
    user_id     INT NOT NULL,
    order_date  DATE NOT NULL,
    amount      DECIMAL(10,2),
    PRIMARY KEY (id, order_date)
) PARTITION BY RANGE (YEAR(order_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
```

**Advantages:**
- ✅ Range queries on shard key are efficient (single shard)
- ✅ Easy to understand and implement
- ✅ Natural for time-series data (partition by date)
- ✅ Easy to add new partitions for future ranges

**Disadvantages:**
- ❌ **Hotspot problem**: If most traffic is on recent data (e.g., "this month's orders"), one shard gets overloaded
- ❌ Uneven distribution if data isn't uniformly spread across ranges
- ❌ Sequential IDs concentrate writes on the last shard

```
Hotspot Problem:
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│   Shard 0      │  │   Shard 1      │  │   Shard 2      │
│  2022 data     │  │  2023 data     │  │  2024 data     │
│  Idle zzz...   │  │  Some traffic  │  │  🔥 ALL writes │
│  Load: 5%      │  │  Load: 20%     │  │  Load: 95%     │
└────────────────┘  └────────────────┘  └────────────────┘
❌ Latest shard is a hotspot — handles almost all traffic!
```

---

#### 2. Hash-Based Sharding

A hash function is applied to the shard key to determine which shard stores the data. Provides even distribution regardless of data patterns.

```
Hash Function: shard_number = hash(shard_key) % num_shards

Example with 4 shards:
  hash("user_123") % 4 = 2  → Shard 2
  hash("user_456") % 4 = 0  → Shard 0
  hash("user_789") % 4 = 3  → Shard 3
  hash("user_012") % 4 = 1  → Shard 1

┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐
│  Shard 0   │  │  Shard 1   │  │  Shard 2   │  │  Shard 3   │
│  user_456  │  │  user_012  │  │  user_123  │  │  user_789  │
│  user_...  │  │  user_...  │  │  user_...  │  │  user_...  │
│  ~25% data │  │  ~25% data │  │  ~25% data │  │  ~25% data │
└────────────┘  └────────────┘  └────────────┘  └────────────┘
✅ Even distribution across all shards
```

**PostgreSQL — Hash Partitioning:**

```sql
-- Create hash-partitioned table
CREATE TABLE users (
    id       BIGSERIAL,
    name     VARCHAR(100),
    email    VARCHAR(255),
    city     VARCHAR(100)
) PARTITION BY HASH (id);

-- Create 4 hash partitions
CREATE TABLE users_p0 PARTITION OF users FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE users_p1 PARTITION OF users FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE users_p2 PARTITION OF users FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE users_p3 PARTITION OF users FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

**Application-Level Hash Sharding (Python):**

```python
import hashlib

NUM_SHARDS = 4

# Database connections per shard
shard_connections = {
    0: "postgresql://shard0-host:5432/mydb",
    1: "postgresql://shard1-host:5432/mydb",
    2: "postgresql://shard2-host:5432/mydb",
    3: "postgresql://shard3-host:5432/mydb",
}

def get_shard(shard_key: str) -> int:
    """Determine which shard a key belongs to."""
    hash_value = int(hashlib.md5(str(shard_key).encode()).hexdigest(), 16)
    return hash_value % NUM_SHARDS

def get_connection(shard_key: str):
    shard_id = get_shard(shard_key)
    return shard_connections[shard_id]

# Usage
user_id = "user_12345"
shard = get_shard(user_id)     # → 2
conn = get_connection(user_id)  # → "postgresql://shard2-host:5432/mydb"
```

**Advantages:**
- ✅ Even data distribution — no hotspots
- ✅ Works with any data type as shard key
- ✅ Simple to compute

**Disadvantages:**
- ❌ **Range queries scatter across all shards**: `WHERE user_id BETWEEN 100 AND 200` hits every shard
- ❌ **Resharding is painful**: Changing number of shards requires moving most data (see Consistent Hashing below)
- ❌ Loss of data locality — related records may land on different shards

```
Resharding Problem (modulus-based):
Before: 3 shards,  hash(key) % 3
After:  4 shards,  hash(key) % 4

  Key "A": hash=7  → 7%3=1 (Shard 1) → 7%4=3 (Shard 3) ← MOVED!
  Key "B": hash=12 → 12%3=0 (Shard 0) → 12%4=0 (Shard 0) ← OK
  Key "C": hash=15 → 15%3=0 (Shard 0) → 15%4=3 (Shard 3) ← MOVED!
  Key "D": hash=9  → 9%3=0 (Shard 0) → 9%4=1 (Shard 1)  ← MOVED!

~75% of keys must move when adding 1 shard! ❌
```

---

#### 3. Consistent Hashing

Solves the resharding problem of basic hash sharding. Keys and nodes are placed on a virtual ring. Each key is assigned to the next node clockwise on the ring.

```
Hash Ring (0 to 360 degrees):

              0°/360°
               │
        Node A ●─────────── ● Node D
       (45°)  /               \ (315°)
             /                 \
            /                   \
   90° ────                     ──── 270°
            \                   /
             \                 /
       Node B ●─────────── ● Node C
       (135°)               (225°)

Key placement (walk clockwise to next node):
  hash("user_1") = 60°   → Node B (next node clockwise after 60°)
  hash("user_2") = 200°  → Node C (next node clockwise after 200°)
  hash("user_3") = 300°  → Node D (next node clockwise after 300°)
  hash("user_4") = 20°   → Node A (next node clockwise after 20°)

Adding Node E at 180°:
  Only keys between 135°-180° move from Node C to Node E
  All other keys stay! (~25% keys move instead of ~75%)
```

**Consistent Hashing Implementation (Python):**

```python
import hashlib
from bisect import bisect_right

class ConsistentHashRing:
    def __init__(self, nodes=None, virtual_nodes=150):
        self.ring = {}           # hash_value → node
        self.sorted_keys = []    # sorted hash values
        self.virtual_nodes = virtual_nodes  # vnodes per physical node

        if nodes:
            for node in nodes:
                self.add_node(node)

    def _hash(self, key: str) -> int:
        return int(hashlib.md5(key.encode()).hexdigest(), 16)

    def add_node(self, node: str):
        """Add a node with virtual nodes for better distribution."""
        for i in range(self.virtual_nodes):
            vnode_key = f"{node}:vnode{i}"
            hash_val = self._hash(vnode_key)
            self.ring[hash_val] = node
            self.sorted_keys.append(hash_val)
        self.sorted_keys.sort()

    def remove_node(self, node: str):
        """Remove a node — only its keys get redistributed."""
        for i in range(self.virtual_nodes):
            vnode_key = f"{node}:vnode{i}"
            hash_val = self._hash(vnode_key)
            del self.ring[hash_val]
            self.sorted_keys.remove(hash_val)

    def get_node(self, key: str) -> str:
        """Find which node a key maps to."""
        if not self.ring:
            return None
        hash_val = self._hash(key)
        idx = bisect_right(self.sorted_keys, hash_val)
        if idx == len(self.sorted_keys):
            idx = 0  # Wrap around the ring
        return self.ring[self.sorted_keys[idx]]

# Usage
ring = ConsistentHashRing(["shard-0", "shard-1", "shard-2"])

print(ring.get_node("user_123"))  # → shard-1
print(ring.get_node("user_456"))  # → shard-0
print(ring.get_node("order_789")) # → shard-2

# Adding a new shard — only ~1/N keys need to move
ring.add_node("shard-3")
print(ring.get_node("user_123"))  # Likely still shard-1 (most keys don't move)
```

**Virtual Nodes (vnodes):**

```
Without vnodes — uneven distribution:
     ●───────────────────────────●──────●
   Node A                     Node B  Node C
   (handles 70% of ring!)    (15%)   (15%)

With vnodes (3 per node) — even distribution:
     A1──B2──C1──A2──B1──C2──A3──B3──C3
   Each physical node handles ~33% of ring ✅

Why vnodes work:
  - More points on ring → more even distribution
  - When a node fails, its load spreads across ALL other nodes
  - Typical: 100-256 vnodes per physical node
```

| Aspect | Modulus Hashing | Consistent Hashing |
|--------|----------------|-------------------|
| **Keys moved on add/remove** | ~N/K of all keys | ~1/K of all keys |
| **Distribution** | Even with good hash | Even with vnodes |
| **Complexity** | O(1) | O(log N) per lookup |
| **Used by** | Simple apps | Cassandra, DynamoDB, Memcached |

---

#### 4. Geographic Sharding

Data is routed to shards based on geographic location, reducing latency for users by keeping data close to them.

```
┌─────────────────────────────────────────────────────────────────┐
│                     GEOGRAPHIC SHARDING                         │
├─────────────────┬──────────────────┬────────────────────────────┤
│   US Shard      │   EU Shard       │   Asia Shard              │
│   (us-east-1)   │   (eu-west-1)    │   (ap-southeast-1)       │
│                 │                  │                            │
│  Users:         │  Users:          │  Users:                    │
│  - United States│  - UK, Germany   │  - India, Japan            │
│  - Canada       │  - France, Italy │  - Singapore, Australia    │
│  - Mexico       │  - Spain, Poland │  - South Korea             │
│                 │                  │                            │
│  Latency: 5ms  │  Latency: 5ms   │  Latency: 5ms             │
│  (local users)  │  (local users)   │  (local users)            │
└─────────────────┴──────────────────┴────────────────────────────┘
         ↑                  ↑                    ↑
    US users write     EU users write      Asia users write
    & read here        & read here         & read here
```

**Application-Level Geographic Routing:**

```python
from enum import Enum

class Region(Enum):
    US = "us"
    EU = "eu"
    ASIA = "asia"

SHARD_CONFIG = {
    Region.US:   "postgresql://us-east-db:5432/mydb",
    Region.EU:   "postgresql://eu-west-db:5432/mydb",
    Region.ASIA: "postgresql://ap-south-db:5432/mydb",
}

# Country to region mapping
COUNTRY_TO_REGION = {
    "US": Region.US, "CA": Region.US, "MX": Region.US,
    "GB": Region.EU, "DE": Region.EU, "FR": Region.EU,
    "IN": Region.ASIA, "JP": Region.ASIA, "SG": Region.ASIA,
}

def get_shard_for_user(country_code: str) -> str:
    region = COUNTRY_TO_REGION.get(country_code, Region.US)  # Default to US
    return SHARD_CONFIG[region]

# Usage
db_url = get_shard_for_user("DE")  # → EU shard
db_url = get_shard_for_user("JP")  # → Asia shard
```

**Advantages:**
- ✅ Low latency — data close to users
- ✅ Data sovereignty compliance (GDPR — EU data stays in EU)
- ✅ Natural data locality

**Disadvantages:**
- ❌ Uneven load if user distribution isn't balanced across regions
- ❌ Cross-region queries are slow and complex
- ❌ Users who travel may hit non-local shards

---

#### 5. Directory-Based Sharding

A separate **lookup service** maintains a mapping of each shard key to its shard. Most flexible but adds a central dependency.

```
┌──────────┐    1. Where is user_123?    ┌────────────────────┐
│  Client   │──────────────────────────→│  Lookup Service    │
└──────────┘                             │  (Directory)       │
                                         │                    │
     2. It's on Shard 2                  │  user_123 → Shard 2│
     ←──────────────────────────────────│  user_456 → Shard 0│
                                         │  user_789 → Shard 1│
     3. Query Shard 2                    │  user_012 → Shard 2│
     ──────────────────────→ Shard 2     └────────────────────┘
```

```python
import redis

class DirectoryShardRouter:
    def __init__(self):
        self.directory = redis.Redis(host='lookup-service', port=6379)
        self.shard_connections = {
            "shard-0": "postgresql://shard0:5432/mydb",
            "shard-1": "postgresql://shard1:5432/mydb",
            "shard-2": "postgresql://shard2:5432/mydb",
        }

    def get_shard(self, key: str) -> str:
        shard_id = self.directory.get(f"shard_map:{key}")
        if shard_id is None:
            # Assign to least-loaded shard
            shard_id = self._find_least_loaded_shard()
            self.directory.set(f"shard_map:{key}", shard_id)
        return self.shard_connections[shard_id.decode()]

    def move_key(self, key: str, new_shard: str):
        """Rebalance: move a key to a different shard."""
        self.directory.set(f"shard_map:{key}", new_shard)

    def _find_least_loaded_shard(self) -> str:
        # Logic to find the shard with least data/load
        return "shard-0"
```

**Advantages:**
- ✅ Maximum flexibility — any key can go to any shard
- ✅ Easy rebalancing — just update the directory
- ✅ No constraints on shard key values

**Disadvantages:**
- ❌ Lookup service is a single point of failure
- ❌ Extra network hop for every query
- ❌ Directory must be highly available and fast (usually Redis/ZooKeeper)

---

### Sharding Strategy Comparison

| Strategy | Distribution | Range Queries | Resharding | Hotspots | Complexity |
|----------|:-----------:|:------------:|:----------:|:--------:|:----------:|
| **Range** | Uneven | ✅ Efficient | Easy (split range) | ❌ Likely | Low |
| **Hash** | Even | ❌ Scatter | ❌ Painful | ✅ Unlikely | Low |
| **Consistent Hash** | Even | ❌ Scatter | ✅ Minimal moves | ✅ Unlikely | Medium |
| **Geographic** | Uneven | Regional only | Moderate | Depends | Medium |
| **Directory** | Flexible | Depends | ✅ Easy | Configurable | High |

---

### Choosing a Shard Key

The shard key is the most critical decision in sharding. A bad shard key leads to hotspots, cross-shard queries, and operational pain.

```
GOOD Shard Key Properties:
┌────────────────────────────────────────────────────────┐
│  ✅ High cardinality (many distinct values)            │
│     → user_id (millions) ✅   status (3 values) ❌    │
│                                                        │
│  ✅ Even distribution                                  │
│     → hash(user_id) ✅   created_date ❌ (skewed)     │
│                                                        │
│  ✅ Query isolation (most queries hit 1 shard)         │
│     → Shard by tenant_id if queries filter on it ✅   │
│                                                        │
│  ✅ Write distribution                                 │
│     → Spread writes across shards ✅                  │
│                                                        │
│  ❌ Avoid monotonically increasing keys               │
│     → auto_increment ID (all writes go to last shard) │
└────────────────────────────────────────────────────────┘
```

**Example — E-commerce Platform:**

```
Shard Key Options:
┌──────────────────────────────────────────────────────────────┐
│ Candidate        │ Pros                │ Cons                │
├──────────────────┼─────────────────────┼─────────────────────┤
│ user_id          │ User queries are    │ Power users create  │
│                  │ single-shard        │ more data (uneven)  │
├──────────────────┼─────────────────────┼─────────────────────┤
│ order_id (hash)  │ Even distribution   │ User's orders span  │
│                  │                     │ all shards (scatter)│
├──────────────────┼─────────────────────┼─────────────────────┤
│ tenant_id (SaaS) │ Perfect isolation   │ Large tenants may   │
│                  │ per tenant          │ need their own shard│
├──────────────────┼─────────────────────┼─────────────────────┤
│ created_date     │ Good for archiving  │ Hotspot on current  │
│                  │                     │ date shard          │
└──────────────────┴─────────────────────┴─────────────────────┘

Best choice: user_id (with hash) — most queries are per-user
```

---

### Cross-Shard Operations

The biggest challenge with sharding — operations that need data from multiple shards.

#### Cross-Shard Queries

```
Query: SELECT * FROM users WHERE age > 25 ORDER BY name LIMIT 10;

Without sharding: Single query, single sort → simple

With sharding (scatter-gather):
┌──────────┐
│  Router   │ → Sends query to ALL shards
└────┬─────┘
     │
     ├──→ Shard 0: SELECT * FROM users WHERE age > 25 ORDER BY name LIMIT 10
     ├──→ Shard 1: SELECT * FROM users WHERE age > 25 ORDER BY name LIMIT 10
     ├──→ Shard 2: SELECT * FROM users WHERE age > 25 ORDER BY name LIMIT 10
     └──→ Shard 3: SELECT * FROM users WHERE age > 25 ORDER BY name LIMIT 10

     Each shard returns up to 10 results (40 total)
     Router merges + sorts + takes top 10

❌ N shards → N queries → slower
❌ LIMIT/OFFSET across shards is complex
❌ Aggregations (COUNT, SUM, AVG) need merge logic
```

#### Cross-Shard JOINs

```
Query: SELECT u.name, o.total
       FROM users u JOIN orders o ON u.id = o.user_id
       WHERE o.status = 'pending';

If users and orders are sharded by DIFFERENT keys:
  → Users on shard by user_id
  → Orders on shard by order_id
  → JOIN requires pulling data from BOTH shard sets

Solutions:
  1. Co-locate related data: Shard both tables by user_id
  2. Denormalize: Store user_name in orders table
  3. Application-level joins: Query both, join in app code
```

#### Distributed Transactions (2PC)

```
Transfer $100 from User A (Shard 1) to User B (Shard 3):

Two-Phase Commit (2PC):

Phase 1 — PREPARE:
┌─────────────────┐
│  Coordinator     │
│  (Transaction    │
│   Manager)       │
└────────┬────────┘
         │ "Can you commit?"
    ┌────┴────┐
    ↓         ↓
┌────────┐ ┌────────┐
│Shard 1 │ │Shard 3 │
│PREPARE │ │PREPARE │
│ -$100  │ │ +$100  │
│ YES ✅ │ │ YES ✅ │
└────────┘ └────────┘

Phase 2 — COMMIT:
┌─────────────────┐
│  Coordinator     │
│  "All said YES"  │
└────────┬────────┘
         │ "COMMIT!"
    ┌────┴────┐
    ↓         ↓
┌────────┐ ┌────────┐
│Shard 1 │ │Shard 3 │
│COMMIT  │ │COMMIT  │
│  ✅    │ │  ✅    │
└────────┘ └────────┘

If any shard says NO in Phase 1 → ABORT all
❌ Problem: Slow (2 round trips) and blocks resources
❌ Problem: Coordinator failure can leave in doubt
```

**Alternative — Saga Pattern (eventual consistency):**

```
Transfer $100: User A → User B

Step 1: Debit $100 from User A (Shard 1) ✅
Step 2: Credit $100 to User B (Shard 3) ✅

If Step 2 fails:
  Compensating action: Credit $100 back to User A (rollback)

✅ No distributed locks
✅ Each step is a local transaction
❌ Temporary inconsistency (between steps)
❌ Must design compensating actions
```

---

### Shard Rebalancing

As data grows unevenly, shards need to be rebalanced — moving data from overloaded shards to underloaded ones.

```
Before Rebalancing:
┌────────────┐  ┌────────────┐  ┌────────────┐
│  Shard 0   │  │  Shard 1   │  │  Shard 2   │
│  50GB      │  │  120GB 🔥  │  │  30GB      │
│  Load: 20% │  │  Load: 90% │  │  Load: 10% │
└────────────┘  └────────────┘  └────────────┘
                    ↑ Overloaded!

After Rebalancing:
┌────────────┐  ┌────────────┐  ┌────────────┐
│  Shard 0   │  │  Shard 1   │  │  Shard 2   │
│  65GB      │  │  70GB      │  │  65GB      │
│  Load: 33% │  │  Load: 35% │  │  Load: 32% │
└────────────┘  └────────────┘  └────────────┘
```

**Rebalancing Strategies:**

| Strategy | How It Works | Downtime | Complexity |
|----------|-------------|----------|------------|
| **Fixed partitions** | Pre-create many partitions, reassign to nodes | Minimal | Low |
| **Dynamic splitting** | Split large partitions in half when they grow | None | Medium |
| **Proportional** | Number of partitions proportional to node count | Minimal | Medium |
| **Virtual shards** | Many virtual shards mapped to fewer physical nodes | None | High |

```
Fixed Partition Strategy (used by Cassandra, Elasticsearch):

Initial: 12 partitions on 3 nodes
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Node 1    │  │   Node 2    │  │   Node 3    │
│ P0 P1 P2 P3│  │ P4 P5 P6 P7│  │ P8 P9 P10 P11│
└─────────────┘  └─────────────┘  └─────────────┘

Add Node 4 → Steal some partitions from each:
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│  Node 1  │  │  Node 2  │  │  Node 3  │  │  Node 4  │
│ P0 P1 P2 │  │ P4 P5 P6 │  │ P8 P9 P10│  │ P3 P7 P11│
└──────────┘  └──────────┘  └──────────┘  └──────────┘
✅ Only 3 partitions moved (not all data reshuffled)
```

---

### Vertical Partitioning

Splitting a table's **columns** across multiple tables or databases. Different from horizontal sharding which splits rows.

```
BEFORE (single wide table):
┌────────────────────────────────────────────────────────────┐
│                        users                               │
├────┬──────┬──────────────────┬──────┬──────────┬──────────┤
│ id │ name │ email            │ bio  │ avatar   │ settings │
│    │      │                  │(TEXT)│ (BLOB)   │ (JSON)   │
├────┼──────┼──────────────────┼──────┼──────────┼──────────┤
│ 1  │ John │ john@example.com │ ...  │ 500KB    │ {...}    │
│ 2  │ Jane │ jane@example.com │ ...  │ 800KB    │ {...}    │
└────┴──────┴──────────────────┴──────┴──────────┴──────────┘
Problem: Loading user list loads 500KB avatars too → slow!

AFTER (vertical partitioning):
┌────────────────────────────────┐    ┌──────────────────────────┐
│     users (hot data)           │    │  user_profiles (cold)    │
├────┬──────┬──────────────────┬─┤    ├──────────┬───────┬───────┤
│ id │ name │ email            │ │    │ user_id  │ bio   │avatar │
├────┼──────┼──────────────────┤ │    ├──────────┼───────┼───────┤
│ 1  │ John │ john@example.com │ │    │ 1        │ ...   │500KB  │
│ 2  │ Jane │ jane@example.com │ │    │ 2        │ ...   │800KB  │
└────┴──────┴──────────────────┘ │    └──────────┴───────┴───────┘
  Fast queries on core data ✅    │    Loaded only when needed ✅
                                  │
                                  │    ┌──────────────────────────┐
                                  │    │  user_settings (cold)    │
                                  │    ├──────────┬───────────────┤
                                  │    │ user_id  │ settings      │
                                  │    ├──────────┼───────────────┤
                                  │    │ 1        │ {...}         │
                                  │    │ 2        │ {...}         │
                                  │    └──────────┴───────────────┘
```

**SQL Implementation:**

```sql
-- Original table
CREATE TABLE users (
    id       SERIAL PRIMARY KEY,
    name     VARCHAR(100),
    email    VARCHAR(255),
    bio      TEXT,
    avatar   BYTEA,
    settings JSONB
);

-- Vertically partitioned:
CREATE TABLE users (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100),
    email VARCHAR(255)
);

CREATE TABLE user_profiles (
    user_id  INT PRIMARY KEY REFERENCES users(id),
    bio      TEXT,
    avatar   BYTEA
);

CREATE TABLE user_settings (
    user_id  INT PRIMARY KEY REFERENCES users(id),
    settings JSONB
);

-- Fetch core data (fast — small rows):
SELECT id, name, email FROM users WHERE id = 123;

-- Fetch profile only when needed (profile page):
SELECT u.name, p.bio, p.avatar
FROM users u JOIN user_profiles p ON u.id = p.user_id
WHERE u.id = 123;
```

**Benefits:**
- ✅ Separate frequently vs rarely accessed data (hot/cold split)
- ✅ Different access patterns can have different indexes
- ✅ Reduce I/O — smaller rows = more rows per page = better cache utilization
- ✅ Can store cold data on cheaper storage

**Disadvantages:**
- ❌ JOINs required to reconstruct full record
- ❌ More complex schema management
- ❌ Transactions span multiple tables

---

### Sharding in Practice — Database-Specific Approaches

#### MongoDB Sharding

MongoDB has built-in sharding with automatic balancing:

```
MongoDB Sharded Cluster Architecture:
┌──────────────┐
│   mongos     │ ← Query router (stateless, multiple for HA)
│   (Router)   │
└──────┬───────┘
       │
┌──────┴───────┐
│ Config Server │ ← Stores shard metadata, chunk mappings
│  (Replica Set)│
└──────┬───────┘
       │
  ┌────┴──────────────────────┐
  ↓              ↓             ↓
┌──────────┐ ┌──────────┐ ┌──────────┐
│ Shard 1  │ │ Shard 2  │ │ Shard 3  │
│(Replica  │ │(Replica  │ │(Replica  │
│  Set)    │ │  Set)    │ │  Set)    │
└──────────┘ └──────────┘ └──────────┘
```

```javascript
// Enable sharding on database
sh.enableSharding("mydb")

// Shard a collection by user_id (hash-based)
sh.shardCollection("mydb.users", { user_id: "hashed" })

// Shard a collection by date (range-based)
sh.shardCollection("mydb.logs", { timestamp: 1 })

// Check shard distribution
db.users.getShardDistribution()

// View chunk distribution across shards
use config
db.chunks.aggregate([
    { $group: { _id: "$shard", count: { $sum: 1 } } }
])
```

#### Vitess (MySQL Sharding)

Vitess is a database clustering system for horizontal scaling of MySQL (used by YouTube, Slack, GitHub):

```
Vitess Architecture:
┌──────────────┐
│  Application  │
└──────┬───────┘
       │ MySQL protocol
┌──────┴───────┐
│    VTGate    │ ← Query router (like MongoDB's mongos)
│  (Stateless) │
└──────┬───────┘
       │
  ┌────┴──────────────────────┐
  ↓              ↓             ↓
┌──────────┐ ┌──────────┐ ┌──────────┐
│ VTTablet │ │ VTTablet │ │ VTTablet │
│ (MySQL)  │ │ (MySQL)  │ │ (MySQL)  │
│ Shard -80│ │Shard 80- │ │ (Replica)│
└──────────┘ └──────────┘ └──────────┘
```

```sql
-- Vitess VSchema (defines sharding strategy)
-- vschema.json:
{
  "sharded": true,
  "vindexes": {
    "hash": {
      "type": "hash"
    }
  },
  "tables": {
    "users": {
      "column_vindexes": [
        {
          "column": "user_id",
          "name": "hash"
        }
      ]
    }
  }
}

-- Queries look like normal MySQL — Vitess routes them
SELECT * FROM users WHERE user_id = 123;
-- → VTGate routes to correct shard automatically
```

#### CockroachDB / YugabyteDB (Automatic Sharding)

NewSQL databases handle sharding automatically:

```sql
-- CockroachDB: Automatic range-based sharding
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name STRING,
    email STRING,
    region STRING
);

-- Hash-sharded index for write-heavy workloads
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ts TIMESTAMP NOT NULL,
    data JSONB
) WITH (
    hash_sharded_primary_index = true
);

-- Geo-partitioning (pin data to regions)
ALTER TABLE users PARTITION BY LIST (region) (
    PARTITION us VALUES IN ('us-east', 'us-west'),
    PARTITION eu VALUES IN ('eu-west', 'eu-central')
);

ALTER PARTITION us OF TABLE users CONFIGURE ZONE USING
    constraints = '[+region=us]';
ALTER PARTITION eu OF TABLE users CONFIGURE ZONE USING
    constraints = '[+region=eu]';
```

---

### When to Shard (and When NOT To)

```
Decision Flowchart:

                    Database performance issues?
                              │
                     ┌────────┴────────┐
                     ↓                 ↓
              Read-heavy?         Write-heavy?
                     │                 │
              ┌──────┴──────┐    ┌─────┴──────┐
              ↓             ↓    ↓            ↓
         Add read      Add cache    Optimize   Vertical
         replicas      (Redis)      queries     scale
              │             │        (indexes)    │
              │             │          │          │
              └──────┬──────┘    ┌─────┴──────┐   │
                     ↓           ↓            ↓   │
              Still not enough?  Still not     │   │
                     │           enough?       │   │
                     ↓           ↓             │   │
              ┌──────────────────┘             │   │
              ↓                               │   │
        NOW consider sharding ← ← ← ← ← ← ← ┘   │
              │                                    │
              ↓                                    │
        Or use NewSQL (CockroachDB, etc.)          │
        for automatic sharding                     │
```

**Shard when:**
- ✅ Single server can't handle write volume
- ✅ Dataset exceeds single machine storage
- ✅ You need data locality (geo-sharding for compliance)
- ✅ You've exhausted vertical scaling + read replicas + caching

**Do NOT shard when:**
- ❌ You can still scale vertically (cheaper and simpler)
- ❌ Read replicas + caching solve the bottleneck
- ❌ Dataset fits on one machine
- ❌ Your queries heavily depend on JOINs across the data
- ❌ Team lacks distributed systems expertise

---

### Summary

```
Sharding Landscape:

┌─────────────────────────────────────────────────────────┐
│  Strategy        │  Best For                            │
├──────────────────┼──────────────────────────────────────┤
│  Range-based     │  Time-series, archival data          │
│  Hash-based      │  Even distribution, point queries    │
│  Consistent Hash │  Dynamic cluster, elastic scaling    │
│  Geographic      │  Multi-region, data sovereignty      │
│  Directory       │  Maximum flexibility, multi-tenant   │
│  Vertical Part.  │  Hot/cold data separation            │
└──────────────────┴──────────────────────────────────────┘
```

**Key Takeaways:**

| Concept | Summary |
|---------|---------|
| **Sharding** | Split rows across servers for write scaling |
| **Partitioning** | Split rows within one server for query pruning |
| **Vertical Partitioning** | Split columns to separate hot/cold data |
| **Shard Key** | Most critical decision — determines distribution and query routing |
| **Consistent Hashing** | Minimizes data movement when adding/removing shards |
| **Cross-Shard** | JOINs, transactions, aggregations all become harder |
| **Rebalancing** | Inevitable — plan for it from the start |
| **When to Shard** | Last resort after replicas, caching, vertical scaling |

For replication strategies that complement sharding, see [Scaling and Replication](scaling-and-replication.md).
