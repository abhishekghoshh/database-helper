
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

---

## BSON Data Types


### String

The `String` BSON type stores UTF-8 encoded text and is the most commonly used data type for textual data such as names, descriptions, and identifiers. MongoDB has no fixed length limit for strings other than the overall 16MB document size limit. String comparisons and sorting respect UTF-8 byte ordering by default unless a collation is specified.

```javascript
db.users.insertOne({ name: "Élise", bio: "Backend engineer" })
```

**Interview Questions:**
- How does MongoDB store and encode string data? — MongoDB stores string data as UTF-8 encoded text within BSON documents, with no fixed length limit beyond the overall 16MB document size cap.
- How can you perform case-insensitive or locale-aware string comparisons in MongoDB? — You can specify a collation (e.g., with strength settings for case-insensitivity) on a collection, index, or individual query/aggregation operation to perform locale-aware and case-insensitive string comparisons.
- Is there a length limit on string fields? — There's no explicit per-string length limit; the only practical constraint is the overall 16MB maximum BSON document size.

### Number Types

MongoDB supports several numeric BSON types: `Int32`, `Int64` (Long), and `Double`, each with different precision and storage size. By default, numbers entered in `mongosh` without a suffix are stored as `Double`, which can cause unexpected precision issues for large integers unless explicitly cast with `NumberInt()` or `NumberLong()`. Choosing the right numeric type matters for both storage efficiency and accurate arithmetic (especially for financial data, where `Decimal128` is often preferred).

```javascript
db.metrics.insertOne({
  views: NumberInt(1000),
  totalRevenueCents: NumberLong(9999999999)
})
```

**Interview Questions:**
- What numeric BSON types does MongoDB support and how do they differ? — MongoDB supports `Int32`, `Int64` (Long), `Double`, and `Decimal128`, differing in storage size and precision, with `Decimal128` providing exact base-10 precision needed for financial calculations that `Double` cannot guarantee.
- Why might you explicitly cast a number to `NumberLong` in mongosh? — Because numbers entered without a suffix in mongosh default to `Double`, explicitly casting with `NumberLong()` avoids floating-point precision issues for large integer values that need exact representation.
- Why is `Decimal128` sometimes preferred over `Double` for monetary values? — `Decimal128` represents decimal values exactly using base-10 floating point, avoiding the rounding errors inherent in `Double`'s binary floating-point representation, which is critical for accurate financial calculations.

### Boolean

The `Boolean` type stores `true` or `false` values and is commonly used for flags such as `isActive` or `isDeleted`. Booleans are frequently used in query filters and are efficiently indexed, though a boolean index alone is usually low-selectivity and often combined with other fields in a compound index.

```javascript
db.users.find({ isActive: true })
```

**Interview Questions:**
- When is it appropriate to index a boolean field? — Indexing a boolean field alone is rarely useful due to low cardinality; it's more appropriate as part of a compound index alongside higher-selectivity fields to narrow down result sets efficiently.
- Why is a standalone index on a low-cardinality boolean field often ineffective? — With only two possible values, a boolean index doesn't narrow down the candidate document set much, so the query planner often still needs to scan a large fraction of the index, providing little performance benefit over a collection scan.

### Date

The `Date` BSON type stores a 64-bit integer representing milliseconds since the Unix epoch (January 1, 1970 UTC), independent of timezone — timezone formatting is a client-side/display concern. Dates should always be stored using the `Date` type (not strings) to enable proper range queries, sorting, and use with TTL indexes for automatic document expiration.

```javascript
db.sessions.insertOne({ userId: 1, createdAt: new Date() })
db.sessions.createIndex({ createdAt: 1 }, { expireAfterSeconds: 3600 })
```

**Interview Questions:**
- How does MongoDB internally store `Date` values? — MongoDB stores `Date` values as a 64-bit integer representing milliseconds since the Unix epoch (January 1, 1970 UTC), independent of any timezone.
- Why should dates be stored as the `Date` type rather than as strings? — Storing dates as the `Date` type enables correct range queries, sorting, and arithmetic, and is required for TTL indexes to automatically expire documents, none of which work reliably with string-formatted dates.
- How do TTL indexes use `Date` fields to expire documents automatically? — A TTL index is created on a `Date` field with an `expireAfterSeconds` option, causing a background process to automatically delete documents once that date field is older than the specified number of seconds.

### ObjectId

`ObjectId` is a special 12-byte BSON type most commonly used as the default value for a document's `_id` field. It's designed to be generated efficiently in a distributed manner without a central coordinator while remaining roughly sortable by creation time. (See the dedicated ObjectId section below for structure details.)

**Interview Questions:**
- Why does MongoDB default to `ObjectId` for the `_id` field instead of an auto-increment integer? — `ObjectId` can be generated independently by clients or servers in a distributed system without needing a central coordinator to hand out sequential values, avoiding the bottleneck and coordination overhead of auto-increment counters.
- Is `ObjectId` guaranteed to be globally unique? Why or why not? — `ObjectId` is not mathematically guaranteed unique but is unique with an extremely high probability in practice, since it combines a timestamp, a random value, and an incrementing counter to minimize collision risk.

### Array

The `Array` BSON type stores an ordered list of values under a single field, and is one of the two composite BSON types (along with embedded documents). Arrays support mixed element types, though consistent typing is best practice for predictable querying. MongoDB automatically creates multikey indexes when an indexed field contains an array.

**Interview Questions:**
- What is a multikey index and how does it relate to array fields? — A multikey index is created automatically when MongoDB indexes a field containing an array, generating an index entry for each array element so queries can efficiently match individual values within it.
- What data types can be stored inside a single array field? — An array can hold a mix of BSON types, including primitives like strings and numbers as well as embedded documents, though consistent typing is best practice for predictable querying.

### Embedded Document

The `Embedded Document` (aka `Object`) BSON type allows a field's value to itself be a full BSON document, enabling nested, hierarchical data structures. This is the mechanism behind "embedding" in MongoDB's data modeling and is queried using dot notation (e.g., `address.city`).

```javascript
db.users.find({ "address.city": "Austin" })
```

**Interview Questions:**
- How do you query fields inside an embedded document? — You query fields inside an embedded document using dot notation, such as `{ "address.city": "Austin" }`, to match a value at a specific nested path.
- What is the practical nesting depth limit for embedded documents in MongoDB? — BSON technically supports nesting up to 100 levels, but practical data models should stay much shallower to keep queries, indexing, and updates manageable and to avoid approaching the 16MB document size limit.

### Null

The `Null` BSON type represents a deliberately empty or unknown value for a field, distinct from a field simply being absent from the document. Queries can distinguish between "field is null" and "field does not exist" using `$exists` combined with equality checks.

```javascript
db.users.find({ middleName: null })              // matches null OR missing field
db.users.find({ middleName: { $exists: true, $eq: null } }) // matches only explicit null
```

**Interview Questions:**
- What is the difference between a field being `null` versus not existing at all? — A field explicitly set to `null` is present in the document with a `Null` BSON value, while a missing field is entirely absent; a plain equality query like `{ field: null }` matches both cases, but `$exists` can distinguish between them.
- How would you query specifically for documents where a field is explicitly set to `null`? — Combine `$exists: true` with `$eq: null`, e.g. `{ middleName: { $exists: true, $eq: null } }`, to match only documents where the field is present and explicitly null, excluding documents where it's missing.

### Binary Data

The `Binary Data` (`BinData`) BSON type stores raw binary content such as images, files, or encrypted blobs directly within a document, subject to the overall 16MB document size limit. For larger files, MongoDB's GridFS specification splits data into chunks stored across multiple documents instead of using a single `BinData` field.

**Interview Questions:**
- When would you store binary data directly in a document versus using GridFS? — Store binary data directly as `BinData` when it's small and well within the 16MB document limit (e.g., thumbnails, small icons), and use GridFS when files exceed or approach that limit, such as large images, videos, or documents.
- What is GridFS and how does it work around the 16MB document size limit? — GridFS is a MongoDB specification that splits large files into smaller chunks stored as separate documents in a `chunks` collection, with metadata tracked in a `files` collection, allowing files far larger than 16MB to be stored and streamed back together.

### Timestamp

The BSON `Timestamp` type is an internal MongoDB type used primarily by the oplog for replication, consisting of a 32-bit seconds value and a 32-bit ordinal counter to disambiguate operations within the same second. It is distinct from the `Date` type and is generally not intended for use in application-level document fields.

**Interview Questions:**
- How does BSON `Timestamp` differ from BSON `Date`? — `Timestamp` is an internal type composed of a 32-bit seconds value plus a 32-bit ordinal counter used to order operations within the same second, whereas `Date` is a 64-bit millisecond value intended for application-level date/time storage.
- Where is the `Timestamp` type primarily used internally in MongoDB? — `Timestamp` is primarily used internally in the oplog to uniquely order replicated operations for replica set synchronization.

### Decimal128

`Decimal128` provides 128-bit decimal floating-point precision, avoiding the rounding errors inherent in binary floating-point (`Double`) representations. It is the recommended type for financial or monetary calculations that require exact decimal precision.

```javascript
db.invoices.insertOne({ amount: NumberDecimal("19.99") })
```

**Interview Questions:**
- Why is `Decimal128` preferred over `Double` for monetary values? — `Decimal128` uses exact base-10 decimal floating-point representation, avoiding the binary floating-point rounding errors that `Double` introduces, which is essential for accurate financial calculations.
- What precision does `Decimal128` provide compared to standard floating-point types? — `Decimal128` provides 128-bit decimal floating-point precision with up to 34 significant decimal digits, far exceeding the precision and exactness guarantees of a standard 64-bit `Double`.

### UUID

MongoDB can store universally unique identifiers using the `Binary` subtype 4 (UUID), often used when integrating with external systems that already generate UUIDs, or when a non-sequential, globally unique identifier is needed outside of `ObjectId`. Drivers typically provide native UUID type mapping for convenience.

**Interview Questions:**
- How is a UUID represented at the BSON level? — A UUID is represented as BSON `Binary` data with subtype 4, storing the 16-byte UUID value, with drivers typically providing native UUID type mapping for convenience.
- When might you use a UUID instead of the default `ObjectId` for `_id`? — You might use a UUID when integrating with external systems that already generate UUIDs, or when you need a globally unique identifier generated independently of MongoDB's own ID scheme.

### MinKey and MaxKey

`MinKey` and `MaxKey` are special BSON types that compare lower than and higher than all other BSON values, respectively, regardless of type. They're primarily used internally for sharding range boundaries and occasionally in queries to bound comparisons across mixed-type fields.

**Interview Questions:**
- What are `MinKey` and `MaxKey` used for in MongoDB? — `MinKey` and `MaxKey` are special values that compare lower than and higher than all other BSON values respectively, used internally for defining open-ended sharding range boundaries and occasionally in queries that need to bound comparisons across mixed types.
- How does sharding use `MinKey`/`MaxKey` for chunk range boundaries? — Sharding uses `MinKey` and `MaxKey` to represent the unbounded lower and upper edges of the very first and last chunk ranges for a shard key, ensuring every possible value is covered by some chunk.

### Regular Expression

The `Regular Expression` BSON type stores a pattern that can be used directly in queries for pattern matching, equivalent to using the `$regex` operator. Regex queries can leverage indexes efficiently only when the pattern is left-anchored (e.g., `^prefix`); unanchored patterns typically require a full collection scan.

```javascript
db.products.find({ sku: { $regex: /^AB-/ } })
```

**Interview Questions:**
- Under what conditions can a regex query use an index efficiently? — A regex query can use an index efficiently only when the pattern is left-anchored (e.g., `^AB-`), allowing the index to be scanned as a range; unanchored or case-insensitive patterns generally force a full collection or full index scan.
- What is the difference between storing a BSON regex versus using `$regex` in a query filter? — A stored BSON regex is a document field value containing a pattern for later matching, while `$regex` in a query filter is an operator applied at query time to match string fields against a pattern.

---

## Schema Validation


### JSON Schema Validation

MongoDB supports document validation rules expressed using a JSON Schema-based syntax (`$jsonSchema`), allowing you to enforce structure, types, required fields, and value constraints on documents in a collection, even though MongoDB is schemaless by default. This gives teams the flexibility of a document model while still enforcing data integrity guarantees similar to a relational schema, and it's commonly adopted incrementally as an application matures.

```javascript
db.createCollection("orders", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["customerId", "total", "status"],
      properties: {
        customerId: { bsonType: "string", description: "must be a string and is required" },
        total: { bsonType: "double", minimum: 0, description: "must be a non-negative number" },
        status: { enum: ["pending", "shipped", "delivered", "cancelled"] }
      }
    }
  }
})
```

**Advantages:**
- Enforces data integrity at the database layer, independent of application code
- Supports gradual, incremental schema enforcement on existing collections

**Disadvantages:**
- Overly strict schemas reduce the flexibility that made MongoDB attractive in the first place
- Validation errors can be less descriptive than application-level validation messages

**Interview Questions:**
- What is `$jsonSchema` used for in MongoDB? — `$jsonSchema` defines a validator that enforces structure, required fields, types, and value constraints on documents in a collection, giving MongoDB relational-like data integrity guarantees while remaining otherwise schemaless.
- How does document validation reconcile with MongoDB's schemaless design philosophy? — Validation is optional and can be applied incrementally or loosely (via `moderate`/`warn` settings), letting teams keep the flexibility of a document model during early development while adding guardrails as the application and data requirements mature.
- Give an example of a field constraint you might enforce with JSON Schema validation. — You might enforce that a `total` field is a non-negative `double` (`{ bsonType: "double", minimum: 0 }`) or that a `status` field is restricted to an enumerated set of valid values like `["pending", "shipped", "delivered", "cancelled"]`.

### Validation Rules

Validation rules are the actual constraints defined within a validator — such as required fields, `bsonType`, `enum` value lists, numeric ranges (`minimum`/`maximum`), string patterns (regex), and nested object/array schemas. Rules can be combined with logical operators like `allOf`, `anyOf`, and `not` for complex constraints, and they apply to `insert` and `update` operations on the collection.

```javascript
db.runCommand({
  collMod: "orders",
  validator: {
    $jsonSchema: {
      properties: {
        email: { bsonType: "string", pattern: "^.+@.+\\..+$" },
        total: { bsonType: "double", minimum: 0, maximum: 100000 }
      }
    }
  }
})
```

**Interview Questions:**
- How would you enforce that a field must match one of a fixed set of values? — Use the `enum` keyword within the field's schema, e.g. `{ status: { enum: ["pending", "shipped", "delivered"] } }`, which rejects any document where the field's value isn't in the specified list.
- How can you validate nested subdocuments or array elements? — Define nested `properties` schemas for subdocuments and an `items` schema for array elements within the `$jsonSchema` validator, allowing validation rules to apply recursively to nested structures.
- What operators let you combine multiple validation rules together? — Logical operators like `allOf`, `anyOf`, `oneOf`, and `not` let you combine multiple validation rules or express more complex conditional constraints within a single validator.

### Validation Levels

The validation level determines which write operations are checked against the validator: `strict` (default) validates all inserts and updates; `moderate` only validates inserts and updates to documents that already satisfy the validation criteria, allowing existing invalid documents to be updated without being forced to become compliant immediately. This is useful when rolling out validation onto a collection that already contains some non-conforming legacy documents.

```javascript
db.runCommand({
  collMod: "orders",
  validationLevel: "moderate"
})
```

**Differences:**

| Level | Applies To |
|---|---|
| `strict` | All inserts and updates must pass validation |
| `moderate` | Only validates inserts and updates to already-valid documents; allows edits to pre-existing invalid documents |
| `off` | Validation disabled entirely |

**Interview Questions:**
- What is the difference between `strict` and `moderate` validation levels? — `strict` validates all inserts and updates against the rules, while `moderate` only validates inserts and updates to documents that already satisfy the rules, letting existing non-conforming documents continue to be edited without being forced into immediate compliance.
- Why would you use `moderate` when introducing validation on an existing collection? — `moderate` avoids breaking application writes to legacy documents that don't yet conform to the new rules, allowing a gradual migration toward full compliance instead of an abrupt cutover.
- How would you temporarily disable validation entirely? — Set `validationLevel` (or the validator itself) to `off`, or run `collMod` to remove/relax the validator temporarily, then re-enable it once ready.

### Validation Actions

The validation action determines what happens when a document fails validation: `error` (default) rejects the write and returns an error to the client, while `warn` logs a warning to the MongoDB log but still allows the write to proceed. `warn` is useful for safely testing new validation rules in production without risking application-breaking write rejections.

```javascript
db.runCommand({
  collMod: "orders",
  validator: { $jsonSchema: { required: ["customerId"] } },
  validationAction: "warn"
})
```

**Differences:**

| Action | Behavior on Invalid Document |
|---|---|
| `error` | Write is rejected, error returned to client |
| `warn` | Write proceeds, warning logged to MongoDB log |

**Interview Questions:**
- What's the practical use case for `validationAction: "warn"`? — `warn` lets you test new validation rules in production by logging violations without rejecting any writes, so you can observe how much existing data or traffic would be affected before enforcing the rule strictly.
- How would you safely roll out a new stricter validation rule to a production collection? — Start with `validationAction: "warn"` and `validationLevel: "moderate"`, monitor the logs for violations, fix or migrate offending data, then progressively switch to `validationAction: "error"` and `validationLevel: "strict"` once confident.
- Where would you find the warnings logged when using the `warn` action? — Validation warnings are written to the MongoDB server log (`mongod` log file or configured log destination).
