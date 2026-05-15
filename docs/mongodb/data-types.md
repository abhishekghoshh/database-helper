
## Primitive types

MongoDB stores data in **BSON** (Binary JSON) format, which extends JSON with additional data types like dates, binary data, and specific numeric types. Understanding BSON types is essential for schema design, querying with `$type`, and avoiding subtle bugs with number precision.

```
BSON Type Hierarchy:

  ┌─────────────────────────────────────────┐
  │              BSON Document              │
  ├─────────────┬───────────────────────────┤
  │  Scalars    │  Complex Types            │
  ├─────────────┼───────────────────────────┤
  │  String     │  Object (embedded doc)    │
  │  Boolean    │  Array                    │
  │  Int32      │  Binary Data              │
  │  Int64      │                           │
  │  Double     │  Special Types            │
  │  Decimal128 │  ──────────────           │
  │  ObjectId   │  Timestamp                │
  │  Date       │  Regex                    │
  │  Null       │  MinKey / MaxKey          │
  │  Undefined  │  JavaScript (code)        │
  └─────────────┴───────────────────────────┘
```

**Common BSON Types Reference:**

| Type | Number | Example | Shell Constructor |
|------|:------:|---------|-------------------|
| Double | 1 | `12.5` | (default for numbers in shell) |
| String | 2 | `"hello"` | — |
| Object | 3 | `{a: 1}` | — |
| Array | 4 | `[1, 2, 3]` | — |
| Binary | 5 | — | `BinData(0, "...")` |
| ObjectId | 7 | `ObjectId("...")` | `ObjectId()` |
| Boolean | 8 | `true` / `false` | — |
| Date | 9 | `ISODate("...")` | `new Date()`, `ISODate()` |
| Null | 10 | `null` | — |
| Regex | 11 | `/pattern/` | — |
| Int32 | 16 | `55` | `NumberInt(55)` |
| Timestamp | 17 | — | `Timestamp()` |
| Int64 | 18 | `1000000000` | `NumberLong(1000000000)` |
| Decimal128 | 19 | `12.0009` | `NumberDecimal("12.0009")` |

- Text -> `"Abhishek Ghosh"`
- Boolean -> `true`
- Number -> 
    - `NimberInt()` -> 1
    - `Integer(int32)` -> 55
    - `NumberLong(int64)` -> 1000000000
    - `NumberDecimal` -> 12.0009
- ObjectId -> `ObjectId("62a6fddadb132197c5e8879f")`
- ISODate -> `2022-06-14T05:45:29.379+00:00`
- Timestamp 
- Embedded Documents
- Arrays

`Db.stats()` will bring the statistic of the database.

---

## Document Size Limits

MongoDB has a couple of hard limits - most importantly, a single document in a collection (including all embedded documents it might have) must be less than equal to `16mb`. Additionally, you may only have `100 levels of embedded documents`.

| Limit | Value |
|-------|-------|
| Max document size | **16 MB** |
| Max nesting depth | **100 levels** |
| Max namespace length | **120 bytes** |
| Max index key size | **1024 bytes** |
| Max indexes per collection | **64** |

You can find all limits (in great detail) here: [MongoDB Limits and Thresholds](https://docs.mongodb.com/manual/reference/limits/)

For the data types, MongoDB supports, you find a detailed overview on this page: [BSON Types](https://docs.mongodb.com/manual/reference/bson-types/)

---

## Number Types Deep Dive

**Important data type limits are:**

- Normal integers (int32) can hold a maximum value of `-2,147,483,647 to +2,147,483,647`
- Long integers (int64) can hold a maximum value of `-9,223,372,036,854,775,807 to +9,223,372,036,854,775,807`
- Text can be as long as you want - the limit is the `16mb` restriction for the overall document

| Type | Bits | Range | Use Case |
|------|:----:|-------|----------|
| `NumberInt` (int32) | 32 | ±2.1 billion | Ages, counts, small IDs |
| `NumberLong` (int64) | 64 | ±9.2 quintillion | Timestamps, large counters |
| `Double` | 64 | ±1.7×10³⁰⁸ | General decimals (default) |
| `NumberDecimal` (Decimal128) | 128 | 34 significant digits | Money, scientific precision |

It's also important to understand the difference between `int32 (NumberInt)`, `int64 (NumberLong)` and a normal number as you can enter it in the shell.

The same goes for a `normal double` and `NumberDecimal`.

`NumberInt` creates a `int32` value => `NumberInt(55)` and `NumberLong` creates a `int64` value => `NumberLong(7489729384792)`

If you just use a number e.g. `insertOne({age: 1})`, this will get added as a `normal double` into the database. 

The reason for this is that the shell is based on `JS` which only knows `float/double` values and doesn't differ between `integers` and `floats`.

`NumberDecimal` creates a high-precision double value e.g. `NumberDecimal("12.99")`
This can be helpful for cases where you need (many) exact decimal places for calculations.

```js
// ⚠️ Double precision issue:
0.1 + 0.2 // → 0.30000000000000004

// ✅ NumberDecimal for exact math:
NumberDecimal("0.1") + NumberDecimal("0.2") // → 0.3 (exact)

// For financial data, always use NumberDecimal:
db.accounts.insertOne({
    balance: NumberDecimal("1299.99"),
    currency: "USD"
})
```

When not working with the shell but a MongoDB driver for your app programming language (e.g. PHP, .NET, Node.js, ...), you can use the driver to create these specific numbers.

Example for [Node.js](http://mongodb.github.io/node-mongodb-native/3.1/api/Long.html)


This will allow you to build a `NumberLong` value like this
```js
const Long = require('mongodb').Long;
db.collection('wealth')
    .insert({ value: Long.fromString("121949898291")});
```

## Embedded documents vs reference id

**Intent**: MongoDB's most critical schema design decision is whether to **embed** related data inside a document or store it separately with a **reference** (foreign key). This affects query performance, data consistency, and write patterns.

```
Embedding vs Referencing:

  ┌─ Embedding (Denormalized) ─────────┐     ┌─ Referencing (Normalized) ────────┐
  │                                     │     │                                    │
  │  { _id: 1,                          │     │  // users collection               │
  │    name: "Alice",                   │     │  { _id: 1, name: "Alice" }         │
  │    address: {          ← embedded   │     │                                    │
  │      street: "123 Main",           │     │  // addresses collection            │
  │      city: "NYC"                   │     │  { _id: 101,                        │
  │    }                               │     │    userId: 1,    ← reference        │
  │  }                                 │     │    street: "123 Main",              │
  │                                     │     │    city: "NYC" }                   │
  │  ✅ One query to get all data       │     │                                    │
  │  ⚠️ Duplication if shared          │     │  ✅ No duplication                 │
  │  ⚠️ 16MB doc size limit           │     │  ⚠️ Requires $lookup (JOIN)       │
  └─────────────────────────────────────┘     └────────────────────────────────────┘
```

### Embedding is better for
- Small subdocuments
- Data that does not change regularly
- When eventual consistency is acceptable
- Documents that grow by a small amount
- Data that you'll often need to perform a second query to fetch Fast reads

### References are better for
- Large subdocuments
- Volatile data
- When immediate consistency is necessary
- Documents that grow a large amount
- Data that youll often exclude from the results
- Fast writes

**Decision Quick Reference:**

| Factor | Embed | Reference |
|--------|:-----:|:---------:|
| Read together frequently? | **Yes** | No |
| Subdocument size | Small (<few KB) | Large |
| Data changes often? | No | **Yes** |
| Shared across documents? | No | **Yes** |
| Can exceed 16MB? | Never | Possible |
| Need atomic updates? | **Yes** (single doc) | Need transactions |


Refference : [Data Modeling](https://www.mongodb.com/docs/manual/core/data-model-design/)

We can also use aggregation framework for joining.

The MongoDB `lookup` operator, by definition, `Performs a left outer join to an unshared collection in the same database to filter in documents from the "joined" collection for processing.`
Simply put, using the MongoDB `lookup` operator makes it possible to merge data from the document you are running a query on and the document you want the data from.


**More can be found in the following links**

- [MongoDB Lookup Aggregations: Syntax, Usage & Practical Examples 101](https://hevodata.com/learn/mongodb-lookup/)
- [$lookup (aggregation)](https://www.mongodb.com/docs/manual/reference/operator/aggregation/lookup/)


## Data validation

Though Mongodb is schema less but we real life scenario we must have certain type of structure. We can add validators when we are creating any collection.

**Intent**: Schema validation enforces structure on your "schema-less" database. It ensures documents follow a defined shape — required fields, data types, value constraints — while still allowing flexibility for optional fields.

**Validation Levels and Actions:**

| Setting | Value | Behavior |
|---------|-------|----------|
| `validationLevel` | `"strict"` (default) | Validates all inserts and updates |
| `validationLevel` | `"moderate"` | Only validates documents that already match the schema |
| `validationLevel` | `"off"` | Disables validation |
| `validationAction` | `"error"` (default) | Rejects invalid documents |
| `validationAction` | `"warn"` | Allows invalid documents but logs a warning |

**Creating a collection with validation:**
```js
db.createCollection('posts', {
    validator: {
      $jsonSchema: {
        bsonType: 'object',
        required: ['title', 'text', 'creator', 'comments'],
        properties: {
          title: {
            bsonType: 'string',
            description: 'must be a string and is required'
          },
          text: {
            bsonType: 'string',
            description: 'must be a string and is required'
          },
          creator: {
            bsonType: 'objectId',
            description: 'must be an objectid and is required'
          },
          comments: {
            bsonType: 'array',
            description: 'must be an array and is required',
            items: {
              bsonType: 'object',
              required: ['text', 'author'],
              properties: {
                text: {
                  bsonType: 'string',
                  description: 'must be a string and is required'
                },
                author: {
                  bsonType: 'objectId',
                  description: 'must be an objectid and is required'
                }
              }
            }
          }
        }
      }
    }
  });
```



If the collection is already created, then we can use run command to add validations and also, we can add validation level
```js
db.runCommand({
    collMod: 'posts',
    validator: {
      $jsonSchema: {
        bsonType: 'object',
        required: ['title', 'text', 'creator', 'comments'],
        properties: {
          title: {
            bsonType: 'string',
            description: 'must be a string and is required'
          },
          text: {
            bsonType: 'string',
            description: 'must be a string and is required'
          },
          creator: {
            bsonType: 'objectId',
            description: 'must be an objectid and is required'
          },
          comments: {
            bsonType: 'array',
            description: 'must be an array and is required',
            items: {
              bsonType: 'object',
              required: ['text', 'author'],
              properties: {
                text: {
                  bsonType: 'string',
                  description: 'must be a string and is required'
                },
                author: {
                  bsonType: 'objectId',
                  description: 'must be an objectid and is required'
                }
              }
            }
          }
        }
      }
    },
    validationAction: 'warn'
  });
```

**Helpful Articles/ Docs:**

- [MongoDB Limits and Thresholds](https://docs.mongodb.com/manual/reference/limits/)
- [BSON Types](https://docs.mongodb.com/manual/reference/bson-types/)
- [Schema Validation](https://docs.mongodb.com/manual/core/schema-validation/)

---

## Server Configuration

We can configure mongodb server in with various arguments. We can check all in mongod --help command.

We can also use mongod.cfg to put all our configurations in a file and we can put it inside any folder and to we have use that file when we are about to start the server.

mongod -f /path/mongod.cfg
```
storage:
  dbPath: "/your/path/to/the/db/folder"
systemLog:
  destination: file
  path: "/your/path/to/the/logs.log"
```
Reference: [Self-Managed Configuration File Options](https://www.mongodb.com/docs/manual/reference/configuration-options/)

**Helpful Articles/ Docs:**

- More Details about Config Files: [Self-Managed Configuration File Options](https://docs.mongodb.com/manual/reference/configuration-options/)
- More Details about the Server (mongod) Options: [mongod](https://docs.mongodb.com/manual/reference/program/mongod/)
