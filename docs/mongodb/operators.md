# Complex Operators

MongoDB operators are special keywords prefixed with `$` that extend the query and update language beyond simple equality checks. They let you express complex filters, transformations, and aggregations directly in the database rather than in application code.

```
Operator Categories:

┌────────────────────────────────────────────────────────────┐
│                    MONGODB OPERATORS                        │
├──────────────┬──────────────┬──────────────┬───────────────┤
│  Query &     │   Update     │  Aggregation │  Array        │
│  Projection  │              │  Pipeline    │               │
├──────────────┼──────────────┼──────────────┼───────────────┤
│ $eq, $gt     │ $set, $unset │ $match       │ $all          │
│ $gte, $lt    │ $inc, $mul   │ $group       │ $elemMatch    │
│ $lte, $ne    │ $push, $pull │ $project     │ $size         │
│ $in, $nin    │ $pop         │ $sort        │               │
│ $or, $and    │ $addToSet    │ $limit       │               │
│ $not, $nor   │ $rename      │ $lookup      │               │
│ $exists      │ $min, $max   │ $unwind      │               │
│ $type, $regex│ $currentDate │ $count       │               │
│ $expr        │              │ $bucket      │               │
└──────────────┴──────────────┴──────────────┴───────────────┘
```

---

## Query and Projection Operators

These operators are used inside `find()`, `findOne()`, and the `$match` stage of aggregation pipelines to filter documents.

### Comparison Operators

**$eq**: Matches values that are equal to a specified value.
```js
{ field: { $eq: value } }
```
```js
// Find users aged exactly 25
db.users.find({ age: { $eq: 25 } })
// Shorthand (implicit $eq):
db.users.find({ age: 25 })
```

**$gt**: Matches values that are greater than a specified value.
```js
{ field: { $gt: value } }
```
```js
// Find products with price greater than 100
db.products.find({ price: { $gt: 100 } })
// Works with dates too — find orders after Jan 1, 2024
db.orders.find({ createdAt: { $gt: ISODate("2024-01-01") } })
```

**$gte**: Matches values that are greater than or equal to a specified value.
```js
{ field: { $gte: value } }
```
```js
// Find employees with salary >= 50000
db.employees.find({ salary: { $gte: 50000 } })
```

**$lt**: Matches values that are less than a specified value.
```js
{ field: { $lt: value } }
```
```js
// Find items with stock less than 10 (low stock alert)
db.inventory.find({ stock: { $lt: 10 } })
```

**$lte**: Matches values that are less than or equal to a specified value.
```js
{ field: { $lte: value } }
```
```js
// Find documents created on or before a certain date
db.logs.find({ timestamp: { $lte: ISODate("2024-06-30") } })
```

**$ne**: Matches all values that are not equal to a specified value.
```js
{ field: { $ne: value } }
```
```js
// Find all users whose status is NOT "inactive"
db.users.find({ status: { $ne: "inactive" } })
// ⚠️ $ne cannot use indexes efficiently — prefer $in with allowed values when possible
```

**$in**: Matches any value in the specified array.
```js
{ field: { $in: [value1, value2, ...] } }
```
```js
// Find products in specific categories
db.products.find({ category: { $in: ["electronics", "books", "clothing"] } })
// Equivalent to SQL: WHERE category IN ('electronics', 'books', 'clothing')
```

**$nin**: Matches none of the values specified in an array.
```js
{ field: { $nin: [value1, value2, ...] } }
```
```js
// Find users who are NOT in the roles "admin" or "superadmin"
db.users.find({ role: { $nin: ["admin", "superadmin"] } })
```

**Combining comparison operators** — you can use multiple on the same field:
```js
// Find products with price between 10 and 100 (inclusive)
db.products.find({ price: { $gte: 10, $lte: 100 } })
```

---

## Logical Operators

Logical operators combine multiple conditions. By default, MongoDB applies an implicit `$and` when you specify multiple fields in a query.

**$or**: Joins query clauses with a logical OR, returns all documents that match the conditions of either clause.
```js
{ $or: [ { clause1 }, { clause2 } ] }
```
```js
// Find users who are either admin OR have age > 30
db.users.find({ $or: [{ role: "admin" }, { age: { $gt: 30 } }] })
```

**$and**: Joins query clauses with a logical AND, returns all documents that match the conditions of both clauses.
```js
{ $and: [ { clause1 }, { clause2 } ] }
```
```js
// Explicit $and — needed when querying the SAME field with different operators
db.products.find({ $and: [{ price: { $gt: 10 } }, { price: { $lt: 50 } }] })
// Implicit $and (shorthand — works when fields are different):
db.products.find({ status: "active", stock: { $gt: 0 } })

// ⚠️ You MUST use explicit $and when applying multiple conditions to the same field:
db.products.find({ $and: [{ tags: "sale" }, { tags: "electronics" }] })
// Without $and, the second {tags: ...} would overwrite the first
```

**$not**: Inverts the effect of a query expression and returns documents that do not match the query expression.
```js
{ field: { $not: { clause } } }
```
```js
// Find products where price is NOT greater than 100 (i.e., price <= 100 or price doesn't exist)
db.products.find({ price: { $not: { $gt: 100 } } })
// ⚠️ $not also matches documents where the field does NOT exist
```

**$nor**: Joins query clauses with a logical NOR, returns all documents that fail to match both clauses.
```js
{ $nor: [ { clause1 }, { clause2 } ] }
```
```js
// Find users who are neither "admin" nor older than 65
db.users.find({ $nor: [{ role: "admin" }, { age: { $gt: 65 } }] })
```

---

## Element Operators

These check for the existence or type of a field — useful because MongoDB is schema-less and documents in the same collection can have different structures.

**$exists**: Matches documents that have (or don't have) a specific field.
```js
{ field: { $exists: true } }   // field is present (even if null)
{ field: { $exists: false } }  // field is absent
```
```js
// Find users who have a phone number field
db.users.find({ phone: { $exists: true } })
// Find users who have phone AND it's not null
db.users.find({ phone: { $exists: true, $ne: null } })
```

**$type**: Matches documents where a field is a specific BSON type.
```js
{ field: { $type: "string" } }
{ field: { $type: ["string", "int"] } }  // multiple types (OR)
```
```js
// Find documents where age is stored as a string (data quality check)
db.users.find({ age: { $type: "string" } })
// BSON types: "double", "string", "object", "array", "binData", "objectId",
//             "bool", "date", "null", "regex", "int", "long", "decimal", "timestamp"
```

---

## Evaluation Operators

**$regex**: Matches strings using regular expressions.
```js
{ field: { $regex: /pattern/, $options: "i" } }
```
```js
// Case-insensitive search for names starting with "john"
db.users.find({ name: { $regex: /^john/i } })
// ⚠️ Regex queries are slow on large collections — use text indexes for full-text search
```

**$expr**: Allows use of aggregation expressions within the query language. Useful for comparing two fields in the same document.
```js
{ $expr: { <aggregation expression> } }
```
```js
// Find products where quantity sold exceeds quantity in stock
db.products.find({ $expr: { $gt: ["$sold", "$stock"] } })
// Find orders where total exceeds the budget field
db.orders.find({ $expr: { $gt: ["$total", "$budget"] } })
```

---

## Array Operators

**$all**: Matches arrays that contain all elements specified in the query.
```js
{ field: { $all: [value1, value2, ...] } }
```
```js
// Find documents that have BOTH "mongodb" AND "nodejs" in their tags array
db.posts.find({ tags: { $all: ["mongodb", "nodejs"] } })
// Order doesn't matter — unlike exact array match
```

**$elemMatch**: Selects documents if element in the array field matches all the specified $elemMatch conditions.
```js
{ field: { $elemMatch: { clause1, clause2, ... } } }
```
```js
// Find users with a score entry that is BOTH >= 80 AND < 90 in the SAME element
db.users.find({ scores: { $elemMatch: { $gte: 80, $lt: 90 } } })
// Without $elemMatch, conditions can match DIFFERENT elements in the array

// For arrays of objects:
db.users.find({
    experiences: {
        $elemMatch: { company: "Google", current: true }
    }
})
// Finds users currently at Google (both conditions on SAME array element)
```

**$size**: Selects documents if the array field is a specified size.
```js
{ field: { $size: size } }
```
```js
// Find users with exactly 3 hobbies
db.users.find({ hobbies: { $size: 3 } })
// ⚠️ $size only supports exact equality — cannot combine with $gt, $lt
// Workaround: use $expr with $size aggregation operator
db.users.find({ $expr: { $gt: [{ $size: "$hobbies" }, 3] } })
```

---

## Update Operators

### Field Update Operators

**$set**: Sets the value of a field in a document.
```js
{ $set: { field: value } }
```
```js
// Set/update specific fields (other fields remain untouched)
db.users.updateOne({ _id: 1 }, { $set: { name: "Max", status: "active" } })
// Set nested field
db.users.updateOne({ _id: 1 }, { $set: { "address.city": "Berlin" } })
```

**$unset**: Removes the specified field from a document.
```js
{ $unset: { field: "" } }
```
```js
// Remove the "temporary" field from a document
db.users.updateOne({ _id: 1 }, { $unset: { temporary: "" } })
// The value ("") is ignored — only the field name matters
```

**$inc**: Increments the value of the field by the specified amount.
```js
{ $inc: { field: amount } }
```
```js
// Increment page view counter by 1
db.articles.updateOne({ _id: articleId }, { $inc: { views: 1 } })
// Decrement stock by 5
db.products.updateOne({ _id: productId }, { $inc: { stock: -5 } })
// ⚠️ Field is created with the increment value if it doesn't exist
```

**$mul**: Multiplies the value of the field by the specified amount.
```js
{ $mul: { field: amount } }
```
```js
// Apply 10% price increase
db.products.updateMany({}, { $mul: { price: 1.10 } })
// Apply 50% discount
db.products.updateMany({ onSale: true }, { $mul: { price: 0.5 } })
```

**$min / $max**: Updates the field only if the new value is less/greater than the existing value.
```js
{ $min: { field: value } }  // Sets field to value IF value < current
{ $max: { field: value } }  // Sets field to value IF value > current
```
```js
// Track the lowest price ever seen
db.products.updateOne({ _id: 1 }, { $min: { lowestPrice: 29.99 } })
// Track the highest score
db.users.updateOne({ _id: 1 }, { $max: { highScore: 9500 } })
```

**$rename**: Renames a field.
```js
{ $rename: { "oldFieldName": "newFieldName" } }
```
```js
// Rename field across all documents
db.users.updateMany({}, { $rename: { "fname": "firstName" } })
```

**$currentDate**: Sets the value of a field to the current date.
```js
{ $currentDate: { field: true } }  // Sets as Date
{ $currentDate: { field: { $type: "timestamp" } } }  // Sets as Timestamp
```
```js
// Update lastModified to current date
db.orders.updateOne({ _id: 1 }, { $currentDate: { lastModified: true } })
```

---

### Array Update Operators

**$push**: Appends a specified value to an array.
```js
{ $push: { field: value } }
```
```js
// Add a single element
db.users.updateOne({ _id: 1 }, { $push: { hobbies: "reading" } })
// Add multiple elements with $each
db.users.updateOne({ _id: 1 }, { $push: { scores: { $each: [85, 90, 92] } } })
// Add with sort and limit (keep top 5 scores)
db.users.updateOne({ _id: 1 }, {
    $push: { scores: { $each: [95], $sort: -1, $slice: 5 } }
})
```

**$addToSet**: Adds a value to an array only if it doesn't already exist (prevents duplicates).
```js
{ $addToSet: { field: value } }
```
```js
// Add tag only if not already present
db.posts.updateOne({ _id: 1 }, { $addToSet: { tags: "mongodb" } })
// Add multiple unique values
db.posts.updateOne({ _id: 1 }, { $addToSet: { tags: { $each: ["mongodb", "nosql"] } } })
```

**$pop**: Removes the first or last element of an array.
```js
{ $pop: { field: 1 } } // Removes the last element
{ $pop: { field: -1 } } // Removes the first element
```
```js
// Remove the most recent log entry (last element)
db.servers.updateOne({ _id: 1 }, { $pop: { logs: 1 } })
```

**$pull**: Removes all array elements that match a specified query.
```js
{ $pull: { field: { clause } } }
```
```js
// Remove all scores less than 60
db.users.updateOne({ _id: 1 }, { $pull: { scores: { $lt: 60 } } })
// Remove a specific object from array
db.users.updateOne({ _id: 1 }, { $pull: { hobbies: { title: "Hiking" } } })
```

**$pullAll**: Removes all matching values from an array.
```js
{ $pullAll: { field: [value1, value2] } }
```
```js
// Remove specific values
db.users.updateOne({ _id: 1 }, { $pullAll: { tags: ["old", "deprecated"] } })
```

### Positional Operators (for array updates)

```js
// $ — update the FIRST matching array element
db.users.updateOne(
    { _id: 1, "scores.subject": "math" },
    { $set: { "scores.$.grade": "A" } }
)

// $[] — update ALL array elements
db.users.updateMany({}, { $inc: { "scores.$[].value": 5 } })

// $[<identifier>] — update elements matching arrayFilters
db.users.updateOne(
    { _id: 1 },
    { $set: { "scores.$[elem].passed": true } },
    { arrayFilters: [{ "elem.value": { $gte: 60 } }] }
)
```

---

## Aggregation Operators

These operators are used inside the **aggregation pipeline** (`db.collection.aggregate([...])`) to transform and analyze data across multiple stages.

**$match**: Filters the documents to pass only documents that match the specified condition(s) to the next pipeline stage.
```js
{ $match: { clause } }
```
```js
// Filter for active users (usually the first stage for efficiency)
{ $match: { status: "active", age: { $gte: 18 } } }
// ⚠️ Place $match as early as possible to reduce documents flowing through the pipeline
```

**$group**: Groups input documents by a specified identifier expression and applies the accumulator expression(s), if specified, to each group.
```js
{ $group: { _id: "$field", total: { $sum: "$amount" } } }
```
```js
// Group orders by customer and calculate totals
{ $group: {
    _id: "$customerId",
    totalSpent: { $sum: "$amount" },
    orderCount: { $sum: 1 },
    avgOrder: { $avg: "$amount" },
    firstOrder: { $min: "$date" },
    lastOrder: { $max: "$date" },
    items: { $push: "$item" }      // Collect all items into an array
}}
// _id: null groups ALL documents into a single group
{ $group: { _id: null, totalRevenue: { $sum: "$amount" } } }
```

**$project**: Passes along the documents with only the specified fields to the next stage in the pipeline.
```js
{ $project: { field1: 1, field2: 1, _id: 0 } }
```
```js
// Compute new fields and reshape documents
{ $project: {
    fullName: { $concat: ["$firstName", " ", "$lastName"] },
    totalPrice: { $multiply: ["$price", "$quantity"] },
    year: { $year: "$createdAt" },
    _id: 0
}}
```

**$sort**: Sorts all input documents and outputs them to the next stage in the specified sort order.
```js
{ $sort: { field: 1 } } // Ascending order
{ $sort: { field: -1 } } // Descending order
```

**$limit**: Passes the first n documents unmodified to the pipeline where n is the specified limit.
```js
{ $limit: n }
```

**$skip**: Skips the first n documents and passes the rest.
```js
{ $skip: n }
```

**$unwind**: Deconstructs an array field, outputting one document per array element.
```js
{ $unwind: "$arrayField" }
```
```js
// If a document has tags: ["a", "b", "c"], $unwind creates 3 documents
// (one with tags: "a", one with tags: "b", one with tags: "c")
{ $unwind: { path: "$tags", preserveNullAndEmptyArrays: true } }
```

**$lookup**: Performs a left outer join with another collection (like SQL JOIN).
```js
{ $lookup: {
    from: "otherCollection",
    localField: "fieldInThisCollection",
    foreignField: "fieldInOtherCollection",
    as: "outputArrayField"
}}
```

**$count**: Returns the count of documents at this stage of the pipeline.
```js
{ $count: "fieldName" }
```

**$bucket**: Groups documents into buckets based on specified boundaries.
```js
{ $bucket: {
    groupBy: "$age",
    boundaries: [0, 18, 30, 50, 100],
    default: "Other",
    output: { count: { $sum: 1 } }
}}
```

**$facet**: Processes multiple aggregation pipelines within a single stage.
```js
{ $facet: {
    "priceStats": [{ $group: { _id: null, avgPrice: { $avg: "$price" } } }],
    "topRated": [{ $sort: { rating: -1 } }, { $limit: 5 }]
}}
```

**$out / $merge**: Write aggregation results to a collection.
```js
{ $out: "outputCollection" }     // Replaces entire collection
{ $merge: { into: "collection" } }  // Merges into existing collection
```

---

## Quick Reference Table

| Category | Operator | Purpose |
|----------|----------|---------|
| **Comparison** | `$eq, $gt, $gte, $lt, $lte, $ne` | Compare field values |
| **Comparison** | `$in, $nin` | Match against a list of values |
| **Logical** | `$and, $or, $not, $nor` | Combine conditions |
| **Element** | `$exists, $type` | Check field presence/type |
| **Evaluation** | `$regex, $expr, $text` | Pattern matching, field comparison, text search |
| **Array** | `$all, $elemMatch, $size` | Query array contents |
| **Update** | `$set, $unset, $inc, $mul` | Modify field values |
| **Update** | `$min, $max, $rename, $currentDate` | Conditional update, rename, timestamps |
| **Array Update** | `$push, $pull, $pop, $addToSet` | Modify arrays |
| **Positional** | `$, $[], $[<id>]` | Target specific array elements |
| **Aggregation** | `$match, $group, $project, $sort` | Pipeline transformations |
| **Aggregation** | `$lookup, $unwind, $facet, $bucket` | Joins, array expansion, multi-pipeline |