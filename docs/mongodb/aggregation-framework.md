
## Introduction

Aggregation framework is just another find method we could say but it has some other advantages too. In aggregation framework we basically create pipeline of steps which operates on datas of that collection.

**Why use the Aggregation Framework instead of `find()`?**

- `find()` can only filter and project — it cannot group, reshape, compute, or join data
- Aggregation pipelines can transform data through multiple stages, similar to UNIX pipes
- Operations like grouping, summing, averaging, joining collections, and reshaping documents are only possible with aggregation
- The aggregation framework runs on the server, avoiding transferring raw data to the application

```
Aggregation Pipeline Concept:

  Collection (raw documents)
       │
       ↓
  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
  │  $match  │──→│  $group  │──→│ $project │──→│  $sort   │──→ Results
  │ (filter) │   │(aggregate│   │(reshape) │   │(order)   │
  └──────────┘   └──────────┘   └──────────┘   └──────────┘
       Stage 1       Stage 2       Stage 3       Stage 4

  Each stage takes documents in, transforms them, and passes them to the next stage.
  Like UNIX: cat data.txt | grep "active" | sort | head -10
```

**Key Principles:**
- Stages execute in order — output of one stage becomes input for the next
- Place `$match` early to reduce documents flowing through the pipeline (performance)
- The pipeline operates on a **copy** of the data — the original collection is not modified
- Each stage can output a **different shape** of document than it received

---

### Common Aggregation Stages Reference

| Stage | Purpose | SQL Equivalent |
|-------|---------|---------------|
| `$match` | Filter documents | `WHERE` / `HAVING` |
| `$group` | Group and aggregate | `GROUP BY` |
| `$project` | Select/compute fields | `SELECT` |
| `$sort` | Order results | `ORDER BY` |
| `$limit` | Limit output count | `LIMIT` |
| `$skip` | Skip documents | `OFFSET` |
| `$unwind` | Flatten arrays | Lateral join |
| `$lookup` | Join collections | `LEFT OUTER JOIN` |
| `$count` | Count documents | `COUNT(*)` |
| `$addFields` | Add computed fields | `SELECT *, expr AS alias` |
| `$bucket` | Range-based grouping | `CASE WHEN ... GROUP BY` |
| `$facet` | Multiple pipelines | Multiple queries in one |
| `$out` / `$merge` | Write results | `INSERT INTO ... SELECT` |

---

### Aggregation Pipeline Example

This example demonstrates a multi-stage pipeline that filters, groups, projects, filters again, and sorts:

Aggregation Pipeline
```js
db.listingsAndReviews.aggregate([
    {
        $match: {
            number_of_reviews: { $gte: 100 } // Listings with more than 100 reviews
        } 
    },
    {
        $group : {
            _id : "$property_type",        // Group by property type
            count: { $sum : 1 },           // Total listings
            reviewCount: { $sum : "$number_of_reviews" },        // Total reviews
            avgPrice: { $avg : "$price" }, // Average price
        },
    },
    {
        $project: {
            _id: 1,
            count: 1,
            reviewCount: 1,
            avgPrice: { $ceil : "$avgPrice" } // Round up avgPrice
        }
    },
    {
        $match: {
            reviewCount: { $gte: 10000 } // Listings by property with more than 10000 total reviews
        } 
    },
    {
        $sort : { 
            count : -1, // Sort by count descending
            avgPrice: 1 // Sort by avgPrice ascending
        }
    }
])
```

**Step-by-step breakdown:**

```
Original collection: ~5000 listings
       │
  $match (reviews >= 100)  →  ~800 documents pass through
       │
  $group (by property_type)  →  ~15 groups (Apartment, House, etc.)
       │
  $project (round avgPrice)  →  Same 15 groups, reshaped
       │
  $match (reviewCount >= 10000)  →  ~5 groups remain
       │
  $sort (by count desc, avgPrice asc)  →  Final sorted results
```

---

### $lookup (Join)

`$lookup` performs a **left outer join** with another collection in the same database. This is MongoDB's equivalent of SQL `JOIN`.

```js
db.accounts.aggregate([
   {
      $lookup:
        {
          from: "transactions",         // join with 'transactions' collection
          localField: "account_id",     // field from the 'accounts' collection
          foreignField: "account_id",   // field from the 'transactions' collection
          as: "customer_orders"         // output array field
        }
   },
   {
      $match: { $expr: { $lt: [ {$size: "$customer_orders"}, 5 ] } } // filter for documents where 'customer_orders' is < 5
   },
])

```

**How $lookup works:**

```
accounts collection:             transactions collection:
┌──────────────────┐             ┌──────────────────────┐
│ { account_id: 1, │             │ { account_id: 1,     │
│   name: "Alice"} │             │   amount: 500 }      │
│ { account_id: 2, │             │ { account_id: 1,     │
│   name: "Bob" }  │             │   amount: 200 }      │
└──────────────────┘             │ { account_id: 2,     │
                                 │   amount: 100 }      │
                                 └──────────────────────┘

After $lookup:
┌────────────────────────────────────────────┐
│ { account_id: 1, name: "Alice",            │
│   customer_orders: [                       │
│     { account_id: 1, amount: 500 },        │
│     { account_id: 1, amount: 200 }         │
│   ]                                        │
│ }                                          │
│ { account_id: 2, name: "Bob",              │
│   customer_orders: [                       │
│     { account_id: 2, amount: 100 }         │
│   ]                                        │
│ }                                          │
└────────────────────────────────────────────┘
```

---

### $unwind — Flatten Arrays

`$unwind` deconstructs an array field, creating a separate document for each array element. This is essential when you need to aggregate on individual array items.

```js
// Original document:
// { _id: 1, name: "Alice", tags: ["mongodb", "nodejs", "python"] }

db.users.aggregate([
    { $unwind: "$tags" }
])

// Result: 3 separate documents:
// { _id: 1, name: "Alice", tags: "mongodb" }
// { _id: 1, name: "Alice", tags: "nodejs" }
// { _id: 1, name: "Alice", tags: "python" }
```

**Practical use — count tag frequency across all documents:**
```js
db.posts.aggregate([
    { $unwind: "$tags" },
    { $group: { _id: "$tags", count: { $sum: 1 } } },
    { $sort: { count: -1 } },
    { $limit: 10 }
])
// Returns the top 10 most used tags
```

**Preserve documents with empty/missing arrays:**
```js
{ $unwind: { path: "$tags", preserveNullAndEmptyArrays: true } }
// Without this option, documents where tags is [] or missing are dropped
```

---

### $addFields — Compute New Fields

`$addFields` adds new computed fields to documents without removing existing fields (unlike `$project` which requires you to explicitly include fields).

```js
db.orders.aggregate([
    { $addFields: {
        totalWithTax: { $multiply: ["$total", 1.18] },
        isHighValue: { $gte: ["$total", 1000] },
        orderYear: { $year: "$createdAt" }
    }}
])
```

---

### $bucket — Range-Based Grouping

Group documents into ranges (like a histogram):

```js
db.users.aggregate([
    { $bucket: {
        groupBy: "$age",
        boundaries: [0, 18, 30, 45, 60, 100],
        default: "Unknown",
        output: {
            count: { $sum: 1 },
            avgIncome: { $avg: "$income" },
            names: { $push: "$name" }
        }
    }}
])
// Groups users into age ranges: 0-17, 18-29, 30-44, 45-59, 60-99
```

---

### $facet — Multiple Pipelines in One Query

Run multiple aggregation pipelines in parallel on the same input documents:

```js
db.products.aggregate([
    { $facet: {
        "priceStats": [
            { $group: {
                _id: null,
                avgPrice: { $avg: "$price" },
                minPrice: { $min: "$price" },
                maxPrice: { $max: "$price" }
            }}
        ],
        "topRated": [
            { $sort: { rating: -1 } },
            { $limit: 5 },
            { $project: { name: 1, rating: 1 } }
        ],
        "categoryBreakdown": [
            { $group: { _id: "$category", count: { $sum: 1 } } },
            { $sort: { count: -1 } }
        ]
    }}
])
// Returns one document with three arrays: priceStats, topRated, categoryBreakdown
```

---

### $out / $merge — Write Results to a Collection

```js
// $out: REPLACE the entire target collection with pipeline results
db.orders.aggregate([
    { $group: { _id: "$customerId", totalSpent: { $sum: "$amount" } } },
    { $out: "customer_totals" }  // Creates/replaces 'customer_totals' collection
])

// $merge: INSERT or UPDATE into an existing collection (more flexible)
db.orders.aggregate([
    { $group: { _id: "$customerId", totalSpent: { $sum: "$amount" } } },
    { $merge: {
        into: "customer_totals",
        whenMatched: "merge",      // Update existing docs
        whenNotMatched: "insert"   // Insert new docs
    }}
])
```

---

### Real-World Aggregation Examples

**E-commerce: Monthly revenue report:**
```js
db.orders.aggregate([
    { $match: { status: "completed" } },
    { $group: {
        _id: {
            year: { $year: "$createdAt" },
            month: { $month: "$createdAt" }
        },
        totalRevenue: { $sum: "$amount" },
        orderCount: { $sum: 1 },
        avgOrderValue: { $avg: "$amount" }
    }},
    { $sort: { "_id.year": -1, "_id.month": -1 } },
    { $project: {
        _id: 0,
        period: { $concat: [
            { $toString: "$_id.year" }, "-",
            { $toString: "$_id.month" }
        ]},
        totalRevenue: { $round: ["$totalRevenue", 2] },
        orderCount: 1,
        avgOrderValue: { $round: ["$avgOrderValue", 2] }
    }}
])
```

**Social: User activity leaderboard:**
```js
db.activities.aggregate([
    { $match: { timestamp: { $gte: ISODate("2024-01-01") } } },
    { $group: {
        _id: "$userId",
        posts: { $sum: { $cond: [{ $eq: ["$type", "post"] }, 1, 0] } },
        comments: { $sum: { $cond: [{ $eq: ["$type", "comment"] }, 1, 0] } },
        likes: { $sum: { $cond: [{ $eq: ["$type", "like"] }, 1, 0] } },
        totalActions: { $sum: 1 }
    }},
    { $addFields: {
        score: { $add: [
            { $multiply: ["$posts", 10] },
            { $multiply: ["$comments", 5] },
            { $multiply: ["$likes", 1] }
        ]}
    }},
    { $sort: { score: -1 } },
    { $limit: 20 },
    { $lookup: {
        from: "users",
        localField: "_id",
        foreignField: "_id",
        as: "user"
    }},
    { $unwind: "$user" },
    { $project: {
        _id: 0,
        username: "$user.name",
        score: 1,
        posts: 1,
        comments: 1,
        likes: 1
    }}
])
```

---

### Performance Tips

```
Aggregation Pipeline Performance:

✅ DO:
  - Place $match and $limit as early as possible
  - Use indexes — $match and $sort can use indexes (only when first in pipeline)
  - Use $project early to drop unneeded fields (less data through pipeline)
  - Use allowDiskUse: true for large datasets exceeding 100MB memory limit

❌ DON'T:
  - Don't use $group on unfiltered collections (process all documents)
  - Don't $unwind large arrays without $match first
  - Don't $lookup without indexes on the foreign field
```

```js
// Enable disk use for large aggregations (default 100MB memory limit per stage)
db.orders.aggregate([
    { $group: { _id: "$customerId", total: { $sum: "$amount" } } }
], { allowDiskUse: true })

// Check aggregation explain plan
db.orders.explain("executionStats").aggregate([
    { $match: { status: "completed" } },
    { $group: { _id: "$customerId", total: { $sum: "$amount" } } }
])
```