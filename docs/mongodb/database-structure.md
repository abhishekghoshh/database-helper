# Database Structure

## Databases

A MongoDB server can host multiple databases, each acting as an independent namespace containing its own set of collections. Databases are created implicitly the first time data is written to a collection within them (`use myDb` alone does not create the database until a write occurs). Each database has its own set of files on disk (per storage engine allocation) and can have its own users and access controls.

```javascript
use inventoryDb
db.products.insertOne({ name: "Widget" }) // creates inventoryDb on first write
show dbs
```

**Interview Questions:**
- When is a MongoDB database actually created on disk? — A database is only actually created once data is written to a collection within it; simply running `use myDb` switches context but does not persist the database until a write occurs.
- How are databases isolated from one another in terms of access control? — Databases can have their own users and roles scoped specifically to that database, allowing fine-grained access control so a user can be restricted to reading/writing only within particular databases.
- What built-in databases does MongoDB create by default (e.g., `admin`, `local`, `config`)? — MongoDB creates the `admin` database for authentication/authorization data, `local` for replication-related data like the oplog, and `config` for sharded cluster metadata.

## Collections

A collection is a grouping of documents, analogous to a table in a relational database, but without enforcing a rigid schema across its documents. Collections are created implicitly on first insert or explicitly via `createCollection()`, which also allows specifying options like schema validation rules, capped size, or collation. Indexes are defined per collection to optimize query performance.

```javascript
db.createCollection("orders", {
  validator: { $jsonSchema: { bsonType: "object", required: ["customerId", "items"] } }
})
```

**Interview Questions:**
- How does a MongoDB collection differ from a relational table? — A collection groups documents without enforcing a single rigid schema across them, unlike a relational table where every row must conform to the same fixed set of columns.
- What options can you specify when explicitly creating a collection? — When explicitly creating a collection with `createCollection()`, you can specify options like a JSON Schema validator, capped collection size and document count limits, and collation rules.
- What is a capped collection and when would you use one? — A capped collection is a fixed-size collection that automatically overwrites its oldest documents once it reaches its size limit, useful for high-throughput use cases like logging or caching recent events where insertion order matters.

## Documents

A document is the basic unit of data in MongoDB, stored in BSON format, conceptually similar to a JSON object. Each document must have a unique `_id` field within its collection, which acts as the primary key and is automatically indexed. Documents can vary in structure from one another within the same collection, enabling polymorphic data models.

```json
{
  "_id": ObjectId("64f1a2b3c4d5e6f7a8b9c0d1"),
  "name": "Charlie",
  "age": 30,
  "address": { "city": "Seattle", "zip": "98101" }
}
```

**Interview Questions:**
- What role does the `_id` field play in a MongoDB document? — The `_id` field uniquely identifies a document within its collection, acts as the primary key, and is automatically indexed to enforce uniqueness and support fast lookups.
- What is the maximum size of a single BSON document and why does this limit exist? — The maximum BSON document size is 16MB, a limit chosen to prevent excessive use of RAM and network bandwidth for a single document and to encourage efficient data modeling.
- Can two documents in the same collection have completely different fields? Explain the implications. — Yes, MongoDB's dynamic schema allows documents in the same collection to have entirely different fields, which enables flexible, polymorphic data models but requires application code to handle missing or varying fields defensively.

## Fields

Fields are the key-value pairs that make up a document, similar to columns in a relational row, but not required to be consistent across documents in a collection. Field names are strings and values can be any BSON type, including nested documents and arrays. Field order is preserved in storage and retrieval but generally should not be relied upon logically.

**Interview Questions:**
- What data types can a field's value hold in MongoDB? — A field's value can be any BSON type, including strings, numbers, booleans, dates, ObjectIds, arrays, and nested embedded documents.
- Are field names case-sensitive in MongoDB? — Yes, field names in MongoDB are case-sensitive, so `Name` and `name` are treated as distinct fields.
- What restrictions exist on field names (e.g., leading `$`, dots)? — Field names cannot start with a `$` character and cannot contain the `.` character, since both are reserved for MongoDB's query operators and dot-notation path syntax.

## Embedded Documents

Embedded documents are documents nested within a field of another document, allowing related data to be co-located and retrieved together in a single read operation. This is a core technique for denormalization in MongoDB's document model, reducing the need for joins/`$lookup`. Embedding is best suited for data that is always accessed together and doesn't grow unboundedly.

```json
{
  "_id": 1,
  "name": "Dana",
  "address": { "street": "123 Main St", "city": "Austin", "zip": "73301" }
}
```

**Interview Questions:**
- What is an embedded document and why would you use one? — An embedded document is a document nested within a field of another document, used to co-locate related data so it can be retrieved together in a single read, reducing the need for joins.
- What are the risks of embedding documents that grow unbounded over time? — Unbounded embedded arrays or documents can push a parent document toward the 16MB size limit, degrade update/read performance, and increase memory pressure, so embedding is best reserved for bounded, tightly related data.
- How deep can BSON document nesting go, and what practical limits should you consider? — BSON supports nesting up to 100 levels deep, but in practice documents should stay much shallower, since deep nesting complicates queries and indexing and increases the risk of approaching the 16MB document size limit.

## Arrays

Arrays allow a single field to hold an ordered list of values, which can be primitives, embedded documents, or a mix of types. MongoDB provides rich query operators (`$elemMatch`, `$size`, `$all`) and update operators (`$push`, `$pull`, `$addToSet`) specifically for working with array fields. Arrays are also central to multikey indexes, which index each element of an array separately.

```javascript
db.students.updateOne(
  { _id: 1 },
  { $push: { grades: 95 } }
)

db.students.find({ grades: { $elemMatch: { $gte: 90 } } })
```

**Interview Questions:**
- How does MongoDB index array fields (multikey indexes)? — MongoDB automatically creates a multikey index when an indexed field contains an array, creating a separate index entry for each element so queries can match any value within the array.
- What is the difference between `$push` and `$addToSet`? — `$push` appends a value to an array regardless of duplicates, while `$addToSet` only adds the value if it doesn't already exist in the array, effectively treating the array like a set.
- How would you query for documents where an array contains a specific value versus an element matching multiple conditions? — Use a simple equality match like `{ grades: 90 }` to find a specific value in the array, and `$elemMatch` (e.g., `{ grades: { $elemMatch: { $gte: 90 } } }`) when a single array element must satisfy multiple conditions simultaneously.

## Dynamic Schema

MongoDB's dynamic (flexible) schema means collections do not enforce a fixed structure by default — documents in the same collection can have different fields or types for the same field. This enables fast iteration during development since schema migrations aren't required to add new fields. However, uncontrolled flexibility can lead to inconsistent data, which is why MongoDB offers optional JSON Schema validation to enforce structure when needed.

**Advantages:**
- Fast iteration without downtime for schema migrations
- Naturally supports polymorphic and evolving data models

**Disadvantages:**
- Risk of inconsistent or malformed data without validation
- Application code must handle missing/optional fields defensively

**Interview Questions:**
- What does "dynamic schema" mean in MongoDB? — Dynamic schema means collections don't enforce a fixed structure by default, so documents within the same collection can have different fields or types for the same field name.
- How can you enforce structure on an otherwise schema-less collection? — You can enforce structure using MongoDB's optional JSON Schema validation, defined via the `validator` option on `createCollection()` or `collMod`, which rejects documents that don't match the specified rules.
- What are the risks of a fully dynamic schema in a large production system? — Without validation, a fully dynamic schema risks inconsistent or malformed data across documents, forcing application code to handle missing or unexpected fields defensively and complicating long-term data quality.
