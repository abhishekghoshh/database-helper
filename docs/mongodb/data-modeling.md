# Data Modeling

## Embedding Documents

Embedding stores related data as nested sub-documents or arrays within a single parent document, favoring read performance and atomicity since the entire related dataset is fetched or updated in a single operation. It works best when related data is accessed together, has a bounded size, and doesn't need to be queried independently at scale.

```json
{
  "_id": 1,
  "name": "Order #1",
  "shippingAddress": { "street": "1 Elm St", "city": "Denver" }
}
```

**Advantages:**
- Single read retrieves all related data (fewer round trips)
- Updates to embedded data are atomic within the document

**Disadvantages:**
- Document can grow toward the 16MB size limit if embedding unbounded arrays
- Duplicated data across documents if the same sub-data appears in multiple parents

**Interview Questions:**
- When is embedding the right modeling choice versus referencing? — Embedding is right when related data is consistently accessed together, has a bounded/predictable size, and doesn't need to be queried independently at scale; referencing is better for large, independently-growing, or shared data.
- What risks arise from embedding a continuously growing array (e.g., comments on a post)? — A continuously growing embedded array can push the parent document toward the 16MB size limit, degrade read/write performance as the document grows, and increase disk relocation overhead.
- How does embedding affect the atomicity of updates to related data? — Because embedded data lives in the same document as its parent, updates to both can be performed atomically in a single write operation, unlike referenced data spread across multiple documents/collections which requires a multi-document transaction for the same guarantee.

## Referencing Documents

Referencing stores a relationship by saving the `_id` (or another key) of a related document instead of embedding its full content, similar to a foreign key in relational databases. Related data is retrieved with a separate query or via the `$lookup` aggregation stage, trading some read performance for reduced duplication and support for larger, independently-growing related datasets.

```javascript
// orders collection references customers by _id
db.orders.aggregate([
  { $match: { _id: 1 } },
  { $lookup: { from: "customers", localField: "customerId", foreignField: "_id", as: "customer" } }
])
```

**Advantages:**
- Avoids data duplication
- Supports large or independently-growing related collections

**Disadvantages:**
- Requires additional queries or `$lookup` joins, impacting read performance
- No native cross-collection referential integrity/foreign key enforcement

**Interview Questions:**
- How do you model a relationship using references instead of embedding? — Store the `_id` (or another key) of the related document in the referencing document, similar to a foreign key, and retrieve the related data with a separate query or a `$lookup` aggregation stage.
- How does `$lookup` work and what are its performance considerations? — `$lookup` performs a left outer join by matching a `localField` in the current collection against a `foreignField` in another collection, but it can be costly at scale since it isn't as optimized as native SQL joins and benefits greatly from an index on the foreign field.
- Does MongoDB enforce referential integrity between referenced collections? — No, MongoDB does not natively enforce foreign key constraints between referenced collections, so the application is responsible for ensuring referenced documents exist and handling orphaned references.

## One-to-One Relationships

A one-to-one relationship associates exactly one document in a collection with exactly one document in another (or embedded within the same document). Simple, bounded one-to-one data (like a user and their profile settings) is typically embedded, while larger or optional one-to-one data might be referenced to keep the primary document lean.

```json
{
  "_id": 1,
  "username": "gwen",
  "profile": { "bio": "Loves databases", "avatarUrl": "https://..." }
}
```

**Interview Questions:**
- Would you embed or reference a one-to-one relationship? What factors influence the decision? — Small, bounded, always-together data is typically embedded, while larger or optional one-to-one data is referenced to keep the primary document lean; the deciding factors are data size, access frequency, and whether the related data is optional.
- Give an example of a one-to-one relationship you'd model by embedding versus referencing. — A user's profile settings (bio, avatar URL) are naturally embedded since they're small and always fetched with the user, whereas a large, rarely-accessed one-to-one dataset like a full audit history document might be referenced instead.

## One-to-Many Relationships

A one-to-many relationship connects one document to multiple related documents, such as a blog post with many comments, or a customer with many orders. The modeling choice depends on scale: a "one-to-few" relationship (e.g., a few addresses per user) is often embedded, while "one-to-many" or "one-to-squillions" (e.g., an order history with thousands of entries, or sensor readings) is typically referenced with the "many" side storing a reference back to the "one" side.

```javascript
// customers collection (one) referenced from orders (many)
db.orders.find({ customerId: 1 })
```

**Interview Questions:**
- How would you decide between embedding and referencing for a one-to-many relationship? — The decision depends on scale: a "one-to-few" relationship (e.g., a handful of addresses per user) is often embedded, while "one-to-many" or "one-to-squillions" relationships (e.g., thousands of orders or sensor readings) are typically referenced with the "many" side storing a reference back to the "one" side.
- What is the "one-to-squillions" pattern and how should it be modeled? — The "one-to-squillions" pattern describes a one-to-many relationship where the "many" side can grow unbounded into the thousands or millions (e.g., sensor readings), and should be modeled by storing a reference to the "one" side on each "many" document rather than embedding them.
- How would you paginate through the "many" side of a one-to-many relationship efficiently? — Use range-based (keyset) pagination filtering on an indexed field like `{ customerId: 1, _id: { $gt: lastId } }` combined with `sort()` and `limit()`, avoiding the performance penalty of `skip()` at large offsets.

## Many-to-Many Relationships

Many-to-many relationships connect multiple documents on each side, such as students enrolled in multiple courses and courses having multiple students. This is typically modeled by storing arrays of references on one or both sides (e.g., an array of `courseIds` on the student document, or a separate join/junction collection for very large or frequently changing relationships).

```json
{ "_id": 1, "name": "Student A", "courseIds": [101, 102, 103] }
```

**Interview Questions:**
- How do you model a many-to-many relationship in MongoDB without a join table? — Store an array of references on one or both sides, such as an array of `courseIds` on each student document and/or an array of `studentIds` on each course document, rather than a relational join table.
- When would you introduce a dedicated junction collection instead of array references? — A junction collection is preferable when the relationship itself carries additional attributes (e.g., enrollment date, grade) or when either side's array of references would grow too large or change too frequently to embed efficiently.
- What are the query implications of storing an array of foreign references on both sides of the relationship? — Storing references on both sides requires keeping both arrays in sync on every relationship change, doubling write complexity, though it simplifies querying from either direction without needing `$lookup`.

## Denormalization

Denormalization intentionally duplicates data across documents/collections to optimize for read performance, avoiding the need for joins at query time. It's a natural fit for MongoDB's document model, but introduces the challenge of keeping duplicated copies in sync when the source data changes.

```json
{
  "_id": 1,
  "orderId": "ORD1",
  "customerName": "Grace",
  "customerEmail": "grace@example.com"
}
```

**Advantages:**
- Faster reads (no joins needed)
- Simplifies read-heavy access patterns

**Disadvantages:**
- Data can become inconsistent if not updated everywhere it's duplicated
- Extra write complexity to propagate changes

**Interview Questions:**
- What is denormalization and why is it common in MongoDB schema design? — Denormalization is intentionally duplicating data across documents/collections to optimize for read performance by avoiding joins at query time, and it's common in MongoDB because the document model favors read efficiency over strict normalization.
- How would you keep denormalized copies of data consistent when the source changes? — You can update all duplicated copies within the same write operation or transaction when the source changes, or use asynchronous background jobs/change streams to propagate updates to denormalized copies, accepting some eventual consistency.
- What's the trade-off between read performance and write complexity with denormalization? — Denormalization speeds up reads by eliminating joins, but increases write complexity and risk of inconsistency since every duplicated copy of the data must be updated whenever the source value changes.

## Schema Design Principles

Effective MongoDB schema design starts from the application's query patterns ("design for your queries") rather than normalizing data first. Key principles include: favor embedding for data accessed together, use references for large or independently-changing data, avoid unbounded array growth, and consider read/write ratios when deciding what to duplicate. Modeling should also account for document growth to avoid frequent document relocation on disk.

**Interview Questions:**
- What does "design your schema based on your application's query patterns" mean in practice? — It means structuring documents and collections around how the application will read and write data, rather than normalizing first, so that the most common queries can be satisfied with minimal joins and efficient index use.
- What factors would push you toward embedding versus referencing for a given relationship? — Data size and growth (bounded vs. unbounded), access patterns (always accessed together vs. independently), and read/write ratio all push the decision — bounded, co-accessed data favors embedding, while large or independently-changing data favors referencing.
- How does anticipated document growth affect your schema design decisions? — Anticipated growth influences whether to embed (risking document relocation and size limits) or reference data, and may lead to pre-allocating space or choosing referencing to keep documents from growing unpredictably large over time.

## Schema Validation

MongoDB supports optional schema validation using JSON Schema rules attached to a collection via `$jsonSchema`, enforced on inserts and updates. Validation can specify required fields, types, value ranges, and more, with configurable validation levels (`strict` or `moderate`) and actions (`error` to reject or `warn` to just log). This lets teams keep MongoDB's flexibility while still guarding against malformed data for critical collections.

```javascript
db.createCollection("users", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["email"],
      properties: {
        email: { bsonType: "string", pattern: "^.+@.+$" },
        age: { bsonType: "int", minimum: 0 }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
})
```

**Interview Questions:**
- How do you enforce structure on a MongoDB collection despite its flexible schema? — You attach a `$jsonSchema` validator to the collection via `createCollection()` or `collMod`, specifying required fields, types, and constraints that are enforced on inserts and updates.
- What is the difference between `validationLevel: "strict"` and `"moderate"`? — `strict` applies validation rules to all inserts and updates, while `moderate` only applies validation to inserts and updates to documents that already satisfy the rules, allowing existing invalid documents to still be modified without being forced to comply immediately.
- What happens to existing documents when you add a validator to a collection that already has data violating the rules? — Existing documents that violate the rules are not automatically modified or rejected; they remain in the collection as-is, but further updates to them may be blocked or allowed depending on the `validationLevel` and `validationAction` settings.

## Polymorphic Documents

Polymorphic documents are documents within the same collection that share some common fields but differ in others based on a "type" discriminator field, useful for modeling entities with shared behavior but different attributes (e.g., different payment methods, or different types of notifications). This pattern leverages MongoDB's flexible schema to avoid separate collections or excessive nullable columns as required in relational databases.

```json
{ "_id": 1, "type": "CREDIT_CARD", "last4": "4242", "expiry": "12/26" }
{ "_id": 2, "type": "PAYPAL", "email": "user@example.com" }
```

**Interview Questions:**
- What is a polymorphic document pattern and when would you use it? — The polymorphic document pattern stores documents with shared common fields but type-specific differing fields in the same collection, distinguished by a discriminator field like `type`; it's useful for modeling entities with shared behavior but different attributes, such as different payment methods.
- How would you query a collection efficiently when documents have a discriminator field? — Index the discriminator field (often as part of a compound index) and filter queries by its value (e.g., `{ type: "CREDIT_CARD" }`) so the query planner can quickly narrow down to the relevant subset of documents.
- How does this pattern compare to modeling the same requirement in a relational database using nullable columns or table inheritance? — In a relational database, this typically requires many nullable columns or complex table inheritance schemes to accommodate varying attributes, whereas MongoDB's flexible schema lets each document naturally carry only the fields relevant to its type without wasted nullable columns.
