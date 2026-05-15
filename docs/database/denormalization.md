# Denormalization

## Blogs and websites


## Medium


## Youtube


## Theory

### What is Denormalization?

**Denormalization** is the deliberate process of adding redundant data to a normalized database to optimize **read performance**. While normalization eliminates redundancy by splitting data into related tables, denormalization reverses this by strategically duplicating data so that queries can retrieve results without expensive JOINs.

**Analogy**: A normalized database is like a well-organized filing cabinet — everything stored once in its proper folder. Denormalization is like photocopying frequently needed documents and placing copies in multiple folders so you don't have to walk across the office to retrieve them every time.

```
NORMALIZED (3NF):
┌──────────┐     ┌──────────────┐     ┌──────────────┐
│  orders   │     │  customers   │     │  products    │
├──────────┤     ├──────────────┤     ├──────────────┤
│ id       │     │ id           │     │ id           │
│ cust_id  │────→│ name         │     │ name         │
│ prod_id  │────→│ email        │     │ price        │
│ quantity │     │ city         │     │ category     │
│ date     │     └──────────────┘     └──────────────┘
└──────────┘
  To get order details: JOIN 3 tables → slow for high traffic

DENORMALIZED:
┌──────────────────────────────────────────────┐
│                order_details                  │
├──────────────────────────────────────────────┤
│ id │ cust_id │ cust_name │ cust_email │      │
│    │ prod_id │ prod_name │ prod_price │      │
│    │ quantity│ date      │ cust_city  │      │
└──────────────────────────────────────────────┘
  Single table read → fast! No JOINs needed
  ❌ But cust_name, prod_name are duplicated across rows
```

---

### Why Denormalize? — The JOIN Problem

As data grows, JOINs become increasingly expensive:

```
Query: "Show all orders with customer name and product name"

NORMALIZED — 3-table JOIN:
┌─────────────────────────────────────────────────────────────────────┐
│ SELECT o.id, c.name, p.name, o.quantity, o.date                    │
│ FROM orders o                                                       │
│ JOIN customers c ON o.cust_id = c.id                                │
│ JOIN products p ON o.prod_id = p.id                                 │
│ WHERE o.date > '2026-01-01';                                        │
│                                                                     │
│ Execution:                                                          │
│   1. Scan orders table         → 10M rows                          │
│   2. For each order, look up customer → 10M index lookups          │
│   3. For each order, look up product  → 10M index lookups          │
│   4. Combine results                                                │
│                                                                     │
│ Time: ~2,500ms   |   Disk reads: ~30M pages                        │
└─────────────────────────────────────────────────────────────────────┘

DENORMALIZED — Single table:
┌─────────────────────────────────────────────────────────────────────┐
│ SELECT id, cust_name, prod_name, quantity, date                     │
│ FROM order_details                                                  │
│ WHERE date > '2026-01-01';                                          │
│                                                                     │
│ Execution:                                                          │
│   1. Scan order_details table → 10M rows (all data in one place)   │
│                                                                     │
│ Time: ~300ms   |   Disk reads: ~10M pages                           │
└─────────────────────────────────────────────────────────────────────┘

Result: ~8x faster by eliminating JOINs
```

**Performance Impact of JOINs at Scale:**

| Table Rows | 2-Table JOIN | 3-Table JOIN | Denormalized |
|-----------|:----------:|:----------:|:----------:|
| 10K | 5ms | 12ms | 3ms |
| 1M | 150ms | 400ms | 50ms |
| 10M | 1,500ms | 4,000ms | 300ms |
| 100M | 15,000ms | Timeout | 2,000ms |

---

### Normalization Levels — Quick Recap

Understanding what you're "un-doing" when you denormalize:

```
Unnormalized (UNF):
┌──────────────────────────────────────────────────────────────┐
│ order_id │ customer │ items                                  │
├──────────┼──────────┼────────────────────────────────────────┤
│ 1        │ John     │ Laptop($999), Mouse($29), Keyboard($79)│
│ 2        │ Jane     │ Phone($699)                             │
└──────────┴──────────┴────────────────────────────────────────┘
❌ Repeating groups, multi-valued fields

1NF — Eliminate repeating groups:
┌──────────┬──────────┬──────────┬─────────┐
│ order_id │ customer │ item     │ price   │
├──────────┼──────────┼──────────┼─────────┤
│ 1        │ John     │ Laptop   │ 999     │
│ 1        │ John     │ Mouse    │ 29      │
│ 1        │ John     │ Keyboard │ 79      │
│ 2        │ Jane     │ Phone    │ 699     │
└──────────┴──────────┴──────────┴─────────┘
❌ "John" repeated for every item in order 1

2NF — Eliminate partial dependencies:
┌──────────┬──────────┐   ┌──────────┬──────────┬─────────┐
│ order_id │ customer │   │ order_id │ item     │ price   │
├──────────┼──────────┤   ├──────────┼──────────┼─────────┤
│ 1        │ John     │   │ 1        │ Laptop   │ 999     │
│ 2        │ Jane     │   │ 1        │ Mouse    │ 29      │
└──────────┴──────────┘   │ 1        │ Keyboard │ 79      │
                          │ 2        │ Phone    │ 699     │
                          └──────────┴──────────┴─────────┘
❌ Price depends on item, not on order_id

3NF — Eliminate transitive dependencies:
  orders(id, cust_id)
  customers(id, name)
  order_items(order_id, prod_id, quantity)
  products(id, name, price)

  ✅ No redundancy, no anomalies
  ❌ 4 JOINs needed to reconstruct order details
```

**Denormalization = strategically moving from 3NF back toward lower forms for performance.**

---

### Denormalization Techniques

#### 1. Storing Computed / Derived Values

Pre-compute and store values that would otherwise require aggregation queries.

```
BEFORE (computed on-the-fly):
┌──────────────────────────────────────────────────────────┐
│ SELECT customer_id,                                      │
│        COUNT(*) AS order_count,                           │
│        SUM(amount) AS total_spent,                        │
│        AVG(amount) AS avg_order                           │
│ FROM orders                                               │
│ GROUP BY customer_id;                                     │
│                                                           │
│ ❌ Scans entire orders table every time                  │
│ ❌ Slow for dashboards showing "Top Customers"           │
└──────────────────────────────────────────────────────────┘

AFTER (pre-computed columns):
┌──────────────────────────────────────────────────────────┐
│              customers                                    │
├──────┬──────┬──────────────┬─────────────┬───────────────┤
│ id   │ name │ order_count  │ total_spent │ avg_order     │
├──────┼──────┼──────────────┼─────────────┼───────────────┤
│ 1    │ John │ 47           │ 12,450.00   │ 264.89        │
│ 2    │ Jane │ 23           │ 8,900.00    │ 386.96        │
└──────┴──────┴──────────────┴─────────────┴───────────────┘
│ ✅ SELECT name, total_spent FROM customers ORDER BY      │
│    total_spent DESC LIMIT 10;  → instant!                │
└──────────────────────────────────────────────────────────┘
```

**PostgreSQL — Maintaining Computed Values with Triggers:**

```sql
-- Add computed columns
ALTER TABLE customers ADD COLUMN order_count INT DEFAULT 0;
ALTER TABLE customers ADD COLUMN total_spent DECIMAL(12,2) DEFAULT 0;

-- Trigger to update on new order
CREATE OR REPLACE FUNCTION update_customer_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE customers
        SET order_count = order_count + 1,
            total_spent = total_spent + NEW.amount
        WHERE id = NEW.customer_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE customers
        SET order_count = order_count - 1,
            total_spent = total_spent - OLD.amount
        WHERE id = OLD.customer_id;
    ELSIF TG_OP = 'UPDATE' THEN
        UPDATE customers
        SET total_spent = total_spent - OLD.amount + NEW.amount
        WHERE id = NEW.customer_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_stats
AFTER INSERT OR UPDATE OR DELETE ON orders
FOR EACH ROW EXECUTE FUNCTION update_customer_stats();
```

**MySQL — Maintaining with Triggers:**

```sql
ALTER TABLE customers ADD COLUMN order_count INT DEFAULT 0;
ALTER TABLE customers ADD COLUMN total_spent DECIMAL(12,2) DEFAULT 0;

DELIMITER //
CREATE TRIGGER after_order_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    UPDATE customers
    SET order_count = order_count + 1,
        total_spent = total_spent + NEW.amount
    WHERE id = NEW.customer_id;
END //
DELIMITER ;
```

**Common Computed Values:**

| Computed Column | Source | Use Case |
|----------------|--------|----------|
| `order_count` | COUNT of orders | Customer dashboards |
| `total_spent` | SUM of order amounts | Revenue reports |
| `last_login_at` | MAX of login timestamps | "Active users" queries |
| `avg_rating` | AVG of review ratings | Product listing pages |
| `follower_count` | COUNT of followers | Social media profiles |
| `unread_count` | COUNT of unread messages | Notification badges |

---

#### 2. Duplicating Data Across Tables

Copy frequently accessed columns from related tables to avoid JOINs.

```
BEFORE (normalized — requires JOIN):
┌───────────────┐          ┌───────────────┐
│    orders      │          │   customers   │
├───────────────┤          ├───────────────┤
│ id            │          │ id            │
│ customer_id ──│────────→ │ name          │
│ amount        │          │ email         │
│ status        │          │ city          │
│ created_at    │          └───────────────┘
└───────────────┘

SELECT o.id, c.name, c.email, o.amount
FROM orders o JOIN customers c ON o.customer_id = c.id
WHERE o.status = 'pending';

AFTER (denormalized — duplicate customer_name):
┌───────────────────────┐
│       orders           │
├───────────────────────┤
│ id                    │
│ customer_id           │
│ customer_name  ← DUP  │
│ customer_email ← DUP  │
│ amount                │
│ status                │
│ created_at            │
└───────────────────────┘

SELECT id, customer_name, customer_email, amount
FROM orders
WHERE status = 'pending';
-- ✅ No JOIN needed!
```

**Implementation with Application-Level Sync:**

```python
# When creating an order, copy customer data
def create_order(customer_id: int, amount: float):
    # Fetch customer data once
    customer = db.execute(
        "SELECT name, email FROM customers WHERE id = %s",
        (customer_id,)
    ).fetchone()

    # Store order with duplicated customer data
    db.execute("""
        INSERT INTO orders (customer_id, customer_name, customer_email, amount, status)
        VALUES (%s, %s, %s, %s, 'pending')
    """, (customer_id, customer["name"], customer["email"], amount))

# When customer updates their name, propagate to orders
def update_customer_name(customer_id: int, new_name: str):
    db.execute("UPDATE customers SET name = %s WHERE id = %s", (new_name, customer_id))
    db.execute("UPDATE orders SET customer_name = %s WHERE customer_id = %s",
               (new_name, customer_id))
    # ❌ If second UPDATE fails → inconsistency!
    # Solution: Wrap in transaction or use eventual consistency
```

**Trigger-Based Propagation:**

```sql
-- Auto-propagate customer name changes to orders
CREATE OR REPLACE FUNCTION propagate_customer_name()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.name <> NEW.name THEN
        UPDATE orders SET customer_name = NEW.name
        WHERE customer_id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_propagate_name
AFTER UPDATE OF name ON customers
FOR EACH ROW EXECUTE FUNCTION propagate_customer_name();
```

---

#### 3. Flattening Hierarchies

Convert parent-child hierarchical data into a flat structure for faster reads.

```
NORMALIZED HIERARCHY (category tree):
┌────────────────────────────┐
│        categories           │
├────┬──────────────┬────────┤
│ id │ name         │parent_id│
├────┼──────────────┼────────┤
│ 1  │ Electronics  │ NULL   │
│ 2  │ Computers    │ 1      │
│ 3  │ Laptops      │ 2      │
│ 4  │ Gaming       │ 3      │
│ 5  │ Phones       │ 1      │
└────┴──────────────┴────────┘

Tree structure:
  Electronics (1)
  ├── Computers (2)
  │   └── Laptops (3)
  │       └── Gaming Laptops (4)
  └── Phones (5)

❌ Finding all ancestors of "Gaming Laptops" requires recursive query:
   Gaming (4) → Laptops (3) → Computers (2) → Electronics (1)
   4 queries or a recursive CTE!
```

**Recursive CTE (slow for deep hierarchies):**

```sql
-- Get full path from leaf to root
WITH RECURSIVE category_path AS (
    SELECT id, name, parent_id, 1 AS depth
    FROM categories WHERE id = 4  -- Gaming Laptops

    UNION ALL

    SELECT c.id, c.name, c.parent_id, cp.depth + 1
    FROM categories c
    JOIN category_path cp ON c.id = cp.parent_id
)
SELECT * FROM category_path;
-- Returns: Gaming → Laptops → Computers → Electronics
-- ❌ One JOIN per level of depth
```

**Denormalized — Materialized Path:**

```sql
-- Store full path as a string
┌────┬──────────────┬────────┬──────────────────────────┐
│ id │ name         │parent_id│ path                    │
├────┼──────────────┼────────┼──────────────────────────┤
│ 1  │ Electronics  │ NULL   │ /1/                      │
│ 2  │ Computers    │ 1      │ /1/2/                    │
│ 3  │ Laptops      │ 2      │ /1/2/3/                  │
│ 4  │ Gaming       │ 3      │ /1/2/3/4/                │
│ 5  │ Phones       │ 1      │ /1/5/                    │
└────┴──────────────┴────────┴──────────────────────────┘

-- Find all ancestors of Gaming Laptops:
SELECT * FROM categories WHERE '/1/2/3/4/' LIKE path || '%';
-- ✅ Single query, no recursion!

-- Find all descendants of Electronics:
SELECT * FROM categories WHERE path LIKE '/1/%';
-- ✅ Single query!
```

**Denormalized — Closure Table:**

```sql
-- Separate table storing ALL ancestor-descendant relationships
CREATE TABLE category_closure (
    ancestor_id   INT REFERENCES categories(id),
    descendant_id INT REFERENCES categories(id),
    depth         INT,
    PRIMARY KEY (ancestor_id, descendant_id)
);

-- For the tree above, closure table contains:
┌─────────────┬───────────────┬───────┐
│ ancestor_id │ descendant_id │ depth │
├─────────────┼───────────────┼───────┤
│ 1           │ 1             │ 0     │  ← self
│ 1           │ 2             │ 1     │  ← Electronics → Computers
│ 1           │ 3             │ 2     │  ← Electronics → Laptops
│ 1           │ 4             │ 3     │  ← Electronics → Gaming
│ 1           │ 5             │ 1     │  ← Electronics → Phones
│ 2           │ 2             │ 0     │  ← self
│ 2           │ 3             │ 1     │  ← Computers → Laptops
│ 2           │ 4             │ 2     │  ← Computers → Gaming
│ 3           │ 3             │ 0     │  ← self
│ 3           │ 4             │ 1     │  ← Laptops → Gaming
│ 4           │ 4             │ 0     │  ← self
│ 5           │ 5             │ 0     │  ← self
└─────────────┴───────────────┴───────┘

-- All ancestors of Gaming (id=4):
SELECT c.* FROM categories c
JOIN category_closure cc ON c.id = cc.ancestor_id
WHERE cc.descendant_id = 4 AND cc.depth > 0;
-- ✅ Single JOIN, no recursion!

-- All descendants of Electronics (id=1):
SELECT c.* FROM categories c
JOIN category_closure cc ON c.id = cc.descendant_id
WHERE cc.ancestor_id = 1 AND cc.depth > 0;
```

**Hierarchy Denormalization Comparison:**

| Approach | Find Ancestors | Find Descendants | Insert | Move Subtree | Storage |
|----------|:---:|:---:|:---:|:---:|:---:|
| **Adjacency List** (normalized) | Recursive CTE | Recursive CTE | O(1) | O(1) | Low |
| **Materialized Path** | LIKE query | LIKE query | O(1) | Update all children | Medium |
| **Closure Table** | Single JOIN | Single JOIN | Insert N rows | Complex | High |
| **Nested Sets** | BETWEEN query | BETWEEN query | Renumber tree | Renumber tree | Low |

---

#### 4. Embedding Related Data (Document-Style)

Store related data as JSON/JSONB within the same row, avoiding separate tables entirely.

```
NORMALIZED:
┌──────────────┐     ┌──────────────────────────┐
│   products    │     │     product_attributes   │
├──────────────┤     ├──────────────────────────┤
│ id           │     │ product_id               │
│ name         │     │ attribute_key            │
│ price        │     │ attribute_value           │
└──────────────┘     └──────────────────────────┘
                     Row 1: (1, 'color', 'red')
                     Row 2: (1, 'size', 'XL')
                     Row 3: (1, 'weight', '200g')

Query: 3-row JOIN to get all attributes for one product

DENORMALIZED (embedded JSON):
┌──────────────────────────────────────────────────────────┐
│   products                                                │
├──────┬──────────┬─────────┬──────────────────────────────┤
│ id   │ name     │ price   │ attributes (JSONB)           │
├──────┼──────────┼─────────┼──────────────────────────────┤
│ 1    │ T-Shirt  │ 29.99   │ {"color":"red",              │
│      │          │         │  "size":"XL",                │
│      │          │         │  "weight":"200g"}            │
└──────┴──────────┴─────────┴──────────────────────────────┘
✅ Single row read — no JOIN
```

**PostgreSQL JSONB:**

```sql
CREATE TABLE products (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(200),
    price      DECIMAL(10,2),
    attributes JSONB DEFAULT '{}'
);

INSERT INTO products (name, price, attributes) VALUES
('Gaming Laptop', 1299.99, '{
    "brand": "ASUS",
    "cpu": "Intel i9",
    "ram": "32GB",
    "gpu": "RTX 4070",
    "screen": "15.6 inch",
    "specs": {"battery": "90Wh", "weight": "2.3kg"}
}');

-- Query by nested JSON field
SELECT name, price, attributes->>'brand' AS brand
FROM products
WHERE attributes->>'cpu' = 'Intel i9';

-- Index on JSONB for fast queries
CREATE INDEX idx_product_attrs ON products USING GIN (attributes);

-- Query with containment operator (uses GIN index)
SELECT * FROM products WHERE attributes @> '{"brand": "ASUS"}';
```

**MongoDB (native document model):**

```javascript
// In MongoDB, embedding IS the default pattern
db.products.insertOne({
    name: "Gaming Laptop",
    price: 1299.99,
    brand: "ASUS",
    specs: {
        cpu: "Intel i9",
        ram: "32GB",
        gpu: "RTX 4070",
        screen: "15.6 inch"
    },
    reviews: [
        { user: "John", rating: 5, text: "Amazing!" },
        { user: "Jane", rating: 4, text: "Great value" }
    ]
});

// Single read gets everything — no JOINs
db.products.findOne({ "specs.cpu": "Intel i9" });
```

---

#### 5. Pre-Joined Tables (Materialized Views)

Create and maintain pre-joined snapshots of frequently queried data.

```
NORMALIZED (3 tables):
orders ──→ customers
orders ──→ products
orders ──→ order_items

Frequent dashboard query:
  SELECT c.name, p.name, oi.quantity, o.total, o.date
  FROM orders o
  JOIN customers c ON o.customer_id = c.id
  JOIN order_items oi ON oi.order_id = o.id
  JOIN products p ON oi.product_id = p.id
  WHERE o.date > NOW() - INTERVAL '30 days';

  ❌ 4-table JOIN, runs every time dashboard loads
```

**PostgreSQL Materialized View:**

```sql
-- Create a pre-joined materialized view
CREATE MATERIALIZED VIEW mv_recent_orders AS
SELECT
    o.id AS order_id,
    o.created_at,
    o.status,
    c.id AS customer_id,
    c.name AS customer_name,
    c.email AS customer_email,
    c.city AS customer_city,
    p.id AS product_id,
    p.name AS product_name,
    p.category,
    oi.quantity,
    oi.unit_price,
    (oi.quantity * oi.unit_price) AS line_total
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE o.created_at > NOW() - INTERVAL '90 days';

-- Add indexes on the materialized view
CREATE INDEX idx_mv_orders_date ON mv_recent_orders(created_at);
CREATE INDEX idx_mv_orders_customer ON mv_recent_orders(customer_id);
CREATE INDEX idx_mv_orders_product ON mv_recent_orders(product_name);

-- Dashboard query is now instant
SELECT customer_name, product_name, quantity, line_total
FROM mv_recent_orders
WHERE created_at > NOW() - INTERVAL '30 days'
ORDER BY created_at DESC;

-- Refresh periodically (manual or scheduled)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_recent_orders;
-- CONCURRENTLY allows reads during refresh (requires unique index)
CREATE UNIQUE INDEX idx_mv_orders_unique ON mv_recent_orders(order_id, product_id);
```

**Scheduled Refresh with pg_cron:**

```sql
-- Refresh every hour
SELECT cron.schedule('refresh_mv_orders', '0 * * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_recent_orders');
```

**MySQL — Equivalent with Summary Tables:**

```sql
-- MySQL doesn't have materialized views, use summary tables
CREATE TABLE order_summary (
    order_id       INT,
    customer_name  VARCHAR(100),
    customer_email VARCHAR(255),
    product_name   VARCHAR(200),
    quantity       INT,
    line_total     DECIMAL(12,2),
    order_date     DATE,
    INDEX idx_date (order_date),
    INDEX idx_customer (customer_name)
);

-- Refresh via scheduled event
CREATE EVENT refresh_order_summary
ON SCHEDULE EVERY 1 HOUR
DO
BEGIN
    TRUNCATE TABLE order_summary;
    INSERT INTO order_summary
    SELECT o.id, c.name, c.email, p.name, oi.quantity,
           oi.quantity * oi.unit_price, o.created_at
    FROM orders o
    JOIN customers c ON o.customer_id = c.id
    JOIN order_items oi ON oi.order_id = o.id
    JOIN products p ON oi.product_id = p.id
    WHERE o.created_at > NOW() - INTERVAL 90 DAY;
END;
```

---

#### 6. Denormalized Counters and Aggregates

Instead of running `COUNT(*)` on large tables, maintain counter columns that are updated on writes.

```
BEFORE — COUNT on every page load:
┌─────────────────────────────────────────┐
│ SELECT COUNT(*) FROM posts              │
│ WHERE subreddit_id = 42;               │
│                                         │
│ Scans index: 500,000 matching rows     │
│ Time: ~200ms                            │
│ ❌ Called 10,000 times/sec on homepage  │
│ ❌ Total DB load: ~2,000 sec/sec 💥   │
└─────────────────────────────────────────┘

AFTER — Pre-computed counter:
┌─────────────────────────────────────────┐
│ subreddits table:                       │
│ ┌────┬──────────┬─────────────┐        │
│ │ id │ name     │ post_count  │        │
│ ├────┼──────────┼─────────────┤        │
│ │ 42 │ r/coding │ 500,000     │        │
│ └────┴──────────┴─────────────┘        │
│                                         │
│ SELECT post_count FROM subreddits      │
│ WHERE id = 42;                          │
│                                         │
│ Time: ~0.1ms (primary key lookup)       │
│ ✅ 2000x faster                         │
└─────────────────────────────────────────┘
```

**Redis as a Denormalized Counter Store:**

```python
import redis

r = redis.Redis()

def create_post(subreddit_id: int, content: str):
    # Insert post into database
    db.execute("INSERT INTO posts (subreddit_id, content) VALUES (%s, %s)",
               (subreddit_id, content))

    # Increment denormalized counter in Redis
    r.incr(f"subreddit:{subreddit_id}:post_count")

    # Also update likes, views, etc.
    r.hincrby(f"subreddit:{subreddit_id}:stats", "total_posts", 1)

def get_post_count(subreddit_id: int) -> int:
    count = r.get(f"subreddit:{subreddit_id}:post_count")
    if count is None:
        # Cache miss — compute and store
        count = db.execute(
            "SELECT COUNT(*) FROM posts WHERE subreddit_id = %s",
            (subreddit_id,)
        ).fetchone()[0]
        r.set(f"subreddit:{subreddit_id}:post_count", count)
    return int(count)

def delete_post(post_id: int, subreddit_id: int):
    db.execute("DELETE FROM posts WHERE id = %s", (post_id,))
    r.decr(f"subreddit:{subreddit_id}:post_count")
```

---

### Trade-offs — Detailed Analysis

```
┌─────────────────────────────────────────────────────────────────────┐
│                NORMALIZATION vs DENORMALIZATION                      │
├──────────────────────────────┬──────────────────────────────────────┤
│        NORMALIZED            │        DENORMALIZED                  │
│                              │                                      │
│  ✅ No data redundancy      │  ❌ Data duplicated across tables    │
│  ✅ Easy updates (one place)│  ❌ Updates must propagate to copies │
│  ✅ Data integrity (FK)     │  ❌ Risk of inconsistency            │
│  ✅ Smaller storage         │  ❌ Larger storage footprint          │
│  ✅ Flexible queries        │  ✅ Predictable query patterns       │
│                              │                                      │
│  ❌ JOINs everywhere        │  ✅ No JOINs (single table reads)   │
│  ❌ Slow reads at scale     │  ✅ Fast reads                       │
│  ❌ Complex queries         │  ✅ Simple queries                   │
│  ❌ More indexes needed     │  ✅ Fewer indexes                    │
└──────────────────────────────┴──────────────────────────────────────┘
```

#### Data Inconsistency Risk

The #1 danger of denormalization:

```
Scenario: Customer changes their name

Normalized (single source of truth):
  UPDATE customers SET name = 'Alice Smith' WHERE id = 1;
  ✅ Done. All queries now return the new name.

Denormalized (name duplicated in orders, invoices, shipments):
  UPDATE customers SET name = 'Alice Smith' WHERE id = 1;
  UPDATE orders SET customer_name = 'Alice Smith' WHERE customer_id = 1;
  UPDATE invoices SET customer_name = 'Alice Smith' WHERE customer_id = 1;
  UPDATE shipments SET customer_name = 'Alice Smith' WHERE customer_id = 1;

  What if the 3rd UPDATE fails?
  ┌───────────────────────────────────────────────┐
  │ customers:  name = 'Alice Smith'  ✅          │
  │ orders:     name = 'Alice Smith'  ✅          │
  │ invoices:   name = 'Alice Smith'  ✅          │
  │ shipments:  name = 'Alice Johnson' ❌ STALE   │
  └───────────────────────────────────────────────┘
  ❌ DATA INCONSISTENCY!
```

**Mitigation Strategies:**

| Strategy | How | Consistency | Complexity |
|----------|-----|:-----------:|:----------:|
| **Database triggers** | Auto-propagate on change | Strong | Medium |
| **Transactional updates** | Wrap all in one transaction | Strong | Medium |
| **Application-level sync** | App code updates all copies | Depends | High |
| **Event-driven** | Publish change events, consumers update | Eventual | High |
| **Periodic reconciliation** | Batch job to fix drift | Eventual | Low |
| **Materialized views** | Database manages the copy | Refresh-based | Low |

---

### Event-Driven Denormalization

For large-scale systems, use events to propagate changes asynchronously:

```
┌───────────┐   UPDATE name   ┌──────────────┐
│ App Server │───────────────→│  customers   │
└─────┬─────┘                 └──────────────┘
      │
      │ Publish event
      ↓
┌──────────────────┐
│  Message Queue   │
│  (Kafka/RabbitMQ)│
│                  │
│ Event:           │
│ {                │
│  "type":         │
│  "customer.      │
│   name.changed", │
│  "customer_id":1,│
│  "old_name":     │
│  "Alice Johnson",│
│  "new_name":     │
│  "Alice Smith"   │
│ }                │
└────────┬─────────┘
         │
    ┌────┴────────────────────────────┐
    ↓              ↓                  ↓
┌──────────┐ ┌──────────┐  ┌────────────────┐
│ Orders   │ │ Invoices │  │ Search Index   │
│ Consumer │ │ Consumer │  │ Consumer       │
│          │ │          │  │ (Elasticsearch)│
│ UPDATE   │ │ UPDATE   │  │ Re-index       │
│ orders   │ │ invoices │  │ customer doc   │
└──────────┘ └──────────┘  └────────────────┘
```

**Kafka Consumer for Propagation (Java):**

```java
@KafkaListener(topics = "customer-events")
public void handleCustomerEvent(CustomerEvent event) {
    if ("customer.name.changed".equals(event.getType())) {
        // Propagate name change to denormalized tables
        orderRepository.updateCustomerName(
            event.getCustomerId(), event.getNewName());
        invoiceRepository.updateCustomerName(
            event.getCustomerId(), event.getNewName());
        log.info("Propagated name change for customer {}",
            event.getCustomerId());
    }
}
```

**Python with Celery (background tasks):**

```python
from celery import shared_task

@shared_task
def propagate_customer_name_change(customer_id: int, new_name: str):
    """Async propagation of denormalized customer name."""
    db.execute("UPDATE orders SET customer_name = %s WHERE customer_id = %s",
               (new_name, customer_id))
    db.execute("UPDATE invoices SET customer_name = %s WHERE customer_id = %s",
               (new_name, customer_id))
    db.execute("UPDATE shipments SET customer_name = %s WHERE customer_id = %s",
               (new_name, customer_id))

# Call after updating customer
def update_customer_name(customer_id: int, new_name: str):
    db.execute("UPDATE customers SET name = %s WHERE id = %s", (new_name, customer_id))
    db.commit()
    # Fire async task — eventual consistency
    propagate_customer_name_change.delay(customer_id, new_name)
```

---

### Denormalization in NoSQL

NoSQL databases are **denormalized by design**. In document databases, the recommended pattern is to embed related data rather than reference it.

```
RELATIONAL (normalized):
  users → orders → order_items → products
  4 tables, 3 JOINs

MONGODB (denormalized by default):
{
  "_id": ObjectId("..."),
  "name": "John",
  "email": "john@example.com",
  "orders": [
    {
      "order_id": "ORD-001",
      "date": "2026-05-15",
      "status": "delivered",
      "items": [
        {
          "product_name": "Laptop",
          "price": 999.99,
          "quantity": 1
        },
        {
          "product_name": "Mouse",
          "price": 29.99,
          "quantity": 2
        }
      ],
      "total": 1059.97
    }
  ],
  "stats": {
    "order_count": 47,
    "total_spent": 12450.00,
    "last_order_date": "2026-05-15"
  }
}

✅ Single document read returns everything
✅ No JOINs, no references
❌ Product name/price duplicated in every order
❌ If product price changes, old orders still show old price
   (This is actually correct for orders — you want historical price!)
```

**When to Embed vs Reference in MongoDB:**

```
EMBED (denormalize) when:
  ✅ Data is read together (order + items)
  ✅ Child doesn't exist without parent (address belongs to user)
  ✅ One-to-few relationship (user has 1-5 addresses)
  ✅ Data rarely changes (historical records)

REFERENCE (normalize) when:
  ✅ Many-to-many relationships (students ↔ courses)
  ✅ Large child documents (16MB document limit)
  ✅ Data changes frequently and must stay consistent
  ✅ One-to-millions relationship (author → posts)
```

---

### When to Denormalize — Decision Framework

```
Decision Flowchart:

              Is the query slow?
                    │
              ┌─────┴─────┐
              ↓            ↓
             No           Yes
              │            │
          Don't        Can indexes fix it?
          denormalize       │
                     ┌──────┴──────┐
                     ↓             ↓
                    Yes            No
                     │             │
                Add indexes   Is it a JOIN problem?
                               │
                        ┌──────┴──────┐
                        ↓             ↓
                       Yes            No
                        │             │
                   Can caching    Profile deeper
                   help?          (CPU? I/O? Locks?)
                        │
                 ┌──────┴──────┐
                 ↓             ↓
                Yes            No
                 │             │
             Use Redis/     NOW denormalize
             Memcached      (as last resort)
                             │
                     ┌───────┴────────┐
                     ↓                ↓
              Read-heavy?      Write-heavy?
                     │                │
            Materialized       DON'T denormalize
            views, pre-       (denormalization makes
            joined tables      writes worse)
```

**Denormalize when:**
- ✅ Read-heavy workloads (>90% reads)
- ✅ JOINs are the proven bottleneck (measured with EXPLAIN ANALYZE)
- ✅ Query patterns are well-known and stable
- ✅ Slight staleness is acceptable (eventual consistency)
- ✅ You've exhausted indexing, caching, and query optimization

**Do NOT denormalize when:**
- ❌ Write-heavy workloads (propagation cost dominates)
- ❌ Data changes frequently (constant propagation)
- ❌ Strong consistency is required (financial, medical)
- ❌ You haven't measured the actual bottleneck yet
- ❌ Query patterns change frequently (schema is hard to change)

---

### Real-World Denormalization Examples

| Company | What They Denormalize | Why |
|---------|----------------------|-----|
| **Twitter** | Fan-out on write — push tweets to all follower timelines | Reading timeline is a single list read, not a JOIN across follows |
| **Facebook** | TAO cache — denormalized social graph | Billions of reads/sec on social connections |
| **Reddit** | Pre-computed vote counts, karma scores | Counting votes per post on every page load is impossible at scale |
| **E-commerce** | Product catalog with embedded reviews, ratings | Product pages need everything in one read |
| **Analytics** | Star schema / OLAP cubes with pre-aggregated metrics | Dashboard queries must be sub-second |

---

### CQRS — Command Query Responsibility Segregation

The architectural pattern that formalizes denormalization at the system level:

```
Traditional (single model for reads + writes):
┌──────────┐    READ + WRITE    ┌──────────────┐
│   App    │───────────────────→│  Single DB   │
└──────────┘                    │  (Normalized) │
                                └──────────────┘

CQRS (separate models):
┌──────────┐    COMMANDS (writes)    ┌──────────────────┐
│   App    │────────────────────────→│  Write Model     │
│          │                         │  (Normalized)    │
│          │                         │  PostgreSQL      │
│          │                         └────────┬─────────┘
│          │                                  │
│          │                           Event/Change Stream
│          │                                  │
│          │                                  ↓
│          │                         ┌──────────────────┐
│          │    QUERIES (reads)      │  Read Model      │
│          │←───────────────────────│  (Denormalized)  │
└──────────┘                         │  Elasticsearch / │
                                     │  Redis / MongoDB │
                                     └──────────────────┘

Write side: Normalized, optimized for data integrity
Read side:  Denormalized, optimized for query performance
Event stream keeps them in sync (eventual consistency)
```

**Benefits of CQRS:**
- ✅ Each model is optimized for its purpose
- ✅ Read and write sides scale independently
- ✅ Read model can use different storage (Elasticsearch for search, Redis for hot data)
- ✅ Multiple read models for different query patterns

---

### Summary

**Key Takeaways:**

| Technique | Best For | Consistency | Maintenance |
|-----------|----------|:-----------:|:-----------:|
| **Computed values** | Aggregates, counts, sums | Trigger-maintained | Low |
| **Duplicated columns** | Eliminating frequent JOINs | Event-driven sync | Medium |
| **Flattened hierarchies** | Tree/graph traversal | Application-managed | Medium |
| **Embedded JSON** | Flexible schemas, EAV patterns | Single-document | Low |
| **Materialized views** | Complex dashboards, reports | Periodic refresh | Low |
| **Pre-computed counters** | High-traffic counts | Trigger/Redis | Low |
| **CQRS** | System-wide read optimization | Eventual | High |

```
The Denormalization Spectrum:

  Fully Normalized (3NF)                    Fully Denormalized
  ◄─────────────────────────────────────────────────────────►
  │                                                         │
  ✅ Data integrity          Balanced approach         ✅ Read performance
  ✅ Easy writes            (most real systems)         ✅ Simple queries
  ❌ Slow reads                                        ❌ Complex writes
  ❌ JOIN-heavy                                        ❌ Inconsistency risk

  OLTP systems tend left ◄──────── ──────────► OLAP systems tend right
```
