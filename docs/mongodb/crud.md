## Overview

**CRUD** stands for **Create, Read, Update, Delete** — the four fundamental operations for persisting and retrieving data in any database. MongoDB provides dedicated methods for each operation that work on **documents** (JSON/BSON objects) stored inside **collections**.

```
CRUD Operations Flow:

Client Application
       │
       ├──── CREATE ────→  insertOne() / insertMany()
       │                   Adds new documents to a collection
       │
       ├──── READ ──────→  find() / findOne()
       │                   Retrieves documents matching a filter
       │
       ├──── UPDATE ────→  updateOne() / updateMany() / replaceOne()
       │                   Modifies existing documents
       │
       └──── DELETE ────→  deleteOne() / deleteMany()
                           Removes documents from a collection
```

**Key Concepts:**
- **Filter**: A query document that specifies which documents to match (like a SQL `WHERE` clause)
- **Options**: Additional configuration such as write concern, collation, upsert, projection, sort, etc.
- **Atomic**: All single-document operations in MongoDB are atomic — a write either fully succeeds or fully fails

---

## Create 
- `insertOne(data, options)` -> for inserting one item
- `insertMany(data, options)` -> for inserting multiple items

**Intent**: Add new documents to a collection. MongoDB auto-generates an `_id` (ObjectId) if not provided. Insert operations respect schema validation rules if configured on the collection.

| Method | Returns | Use When |
|--------|---------|----------|
| `insertOne()` | `{ acknowledged, insertedId }` | Adding a single document |
| `insertMany()` | `{ acknowledged, insertedIds }` | Bulk inserting multiple documents at once |

For detailed insert examples, ordered vs unordered inserts, write concern, and `mongoimport`, see [Create](create.md).

---

## Read 
- `find(filter, options)` -> find all the data based on the filter
- `findOne(filter, options)` -> find the first matching element based on the filter

**Intent**: Retrieve documents from a collection. `find()` returns a **cursor** (lazy iterator that fetches 20 documents at a time in the shell), while `findOne()` returns a single document directly.

| Method | Returns | Use When |
|--------|---------|----------|
| `find()` | Cursor (iterable) | Fetching multiple documents, paginating, sorting |
| `findOne()` | Single document or `null` | Fetching one specific document (by `_id`, unique field, etc.) |

**Common cursor methods chained after `find()`:**

```js
db.coll.find(filter)
    .projection({name: 1, _id: 0})  // Select specific fields
    .sort({age: -1})                  // Sort descending by age
    .skip(20)                         // Skip first 20 results (pagination)
    .limit(10)                        // Return only 10 results
    .count()                          // Count matching documents
```

For detailed read examples, comparison/logical/array operators, cursors, and projection, see [Read](read.md).

---

## Update 
- `updateOne(filter, data, options)` -> to update one document
- `updateMany(filter, data, options)` -> for updating multiple documents
- `replaceOne(filter, data, options)` -> for replacing the entire document

**Intent**: Modify existing documents. Update operations use **update operators** (like `$set`, `$inc`, `$push`) to change specific fields without replacing the whole document. `replaceOne()` replaces the entire document body (except `_id`).

| Method | Returns | Use When |
|--------|---------|----------|
| `updateOne()` | `{ matchedCount, modifiedCount }` | Changing specific fields in one document |
| `updateMany()` | `{ matchedCount, modifiedCount }` | Changing specific fields in multiple documents |
| `replaceOne()` | `{ matchedCount, modifiedCount }` | Replacing an entire document's contents |
| `findOneAndUpdate()` | The document (before or after update) | Need the document value AND want to update atomically |

**Upsert**: Pass `{ upsert: true }` as the third argument to insert a new document if no match is found.

For detailed update examples, array update operators (`$push`, `$pull`, `$addToSet`, `$pop`), and positional operators (`$`, `$[]`, `$[<identifier>]`), see [Update](update.md).

---

## Delete 
- `deleteOne(filter, options)` -> delete only the first item with matching filter
- `deleteMany(filter, options)` -> delete all items matching with the filter

**Intent**: Remove documents from a collection permanently. There is no "soft delete" built into MongoDB — if you need soft delete, add a field like `{ deleted: true }` and filter accordingly.

| Method | Returns | Use When |
|--------|---------|----------|
| `deleteOne()` | `{ deletedCount }` | Removing a single specific document |
| `deleteMany()` | `{ deletedCount }` | Removing multiple documents matching a condition |
| `findOneAndDelete()` | The deleted document | Need the document value before deleting |

⚠️ **Warning**: `db.coll.deleteMany({})` deletes **all documents** in the collection but keeps the collection and its indexes. Use `db.coll.drop()` to remove the collection entirely.

For detailed delete examples and write concern options, see [Delete](delete.md).

---

## Examples

**Delete the first element with `name` as `"Abhishek Ghosh"`:**
```js
db.products.deleteOne({name: "Abhishek Ghosh"})
```

**Update the `age` to `24` where `name` is `"Abhishek Pal"`:**
```js
db.products.updateOne({name: "Abhishek Pal"}, {$set: {age: 24}})
```

**Add a field `height` to all the documents:**
```js
db.products.updateMany({}, {$set: {height: "Unknown"}})
```
`{}` this means all the documents.

**Insert two items at a time:**
```js
db.products.insertMany([
    {name: "Nasim Molla", age: 25},
    {name: "Sayan Mandal", age: 24}
])
```

**Find all the `students` whose `age` is `greater than 24`:**
```js
db.products.find({age: {$gt: 24}})
```

**Print all the `names` but not `_id` for the `student` whose `age` is `greater than 24`:**
```js
db.products.find({age: {$gt: 24}}, {name: 1, _id: 0})
```

**If we use update without `$set` then the document will be replaced with the data we have provided. (Rather use replace than update for full replacement):**
```js
db.products.insertOne({})
// {"acknowledged" : true,"insertedId" : ObjectId("62a7faec7866653913689afd")}

db.products.update({_id: ObjectId("62a7faec7866653913689afd")}, {name: "Anirban Ghosh", age: 23})
// WriteResult({ "nMatched" : 1, "nUpserted" : 0, "nModified" : 1 })

db.products.find({_id: ObjectId("62a7faec7866653913689afd")})
// { "_id" : ObjectId("62a7faec7866653913689afd"), "name" : "Anirban Ghosh", "age" : 23 }
```

**Set status object for age greater than 24:**
```js
db.products.updateMany(
    {age: {$gt: 24}}, 
    {$set: {status: {married: false, single: false}}}
)
```

**If we have a list of strings like hobbies, we can search like this (It will find the first document that has a list of `hobbies` containing `"Drama"`):**
```js
db.products.findOne({hobbies: "Drama"})
```

**We can run a query in a nested object:**
```js
db.products.findOne({"status.single": false})
```

**To get rid of your data, you can simply load the database you want to get rid of (`use databaseName`) and then execute:**
```js
db.dropDatabase()
```

**Similarly, you could get rid of a single collection in a database via:**
```js
db.<collection-name>.drop()
```

## What is cursor?

A **cursor** is a pointer to the result set of a query. Instead of loading all matching documents into memory at once, MongoDB returns a cursor that lazily fetches documents in **batches of 20** (in the shell). This is efficient for large result sets — you only load what you need.

**Why cursors matter:**
- For a query returning 1 million documents, loading all at once would exhaust memory
- Cursors fetch in small batches, keeping memory usage low
- Cursors are server-side objects that **expire after 10 minutes of inactivity**

**Key behaviors:**
- When we find anything in the shell, rather than giving everything in one shot, it gives us the cursor of 20 elements, and to move to the next 20, we have to enter "it". To see it, we can use the `toArray` method on the cursor, which will exhaust the cursor and make one array with all the elements and show that.
- Cursor will fetch only the needed element.
- `findOne` will not give us a cursor object as it will only give us one element.
- `db.products.find().toArray()`
- `db.products.find().forEach((doc) => {printjson(doc)})

```
Cursor Lifecycle:

  db.coll.find({age: {$gt: 20}})
         │
         ↓
  ┌──────────────────┐
  │  Cursor Created  │ ← Server-side pointer to result set
  │  (Batch 1: 20    │
  │   documents)     │
  └────────┬─────────┘
           │  type "it" in shell
           ↓
  ┌──────────────────┐
  │  Batch 2: next   │
  │  20 documents    │
  └────────┬─────────┘
           │  type "it" again
           ↓
  ┌──────────────────┐
  │  Batch 3: ...    │
  └────────┬─────────┘
           │
           ↓
  ┌──────────────────┐
  │  Cursor Exhausted│ ← No more documents
  └──────────────────┘
```

**Common cursor methods:**

| Method | Description |
|--------|-------------|
| `.toArray()` | Exhaust cursor, return all documents as an array |
| `.forEach(fn)` | Iterate through each document with a callback |
| `.count()` | Return total count of matching documents |
| `.hasNext()` | Check if cursor has more documents |
| `.next()` | Get the next document from cursor |
| `.sort({field: 1})` | Sort results (1 = ascending, -1 = descending) |
| `.skip(n)` | Skip first n documents |
| `.limit(n)` | Return at most n documents |
| `.pretty()` | Format output for readability |

## What is projection?

**Projection** controls which fields are returned in query results. Instead of returning the entire document (which may be large), you specify exactly which fields you need. This is similar to `SELECT column1, column2` in SQL instead of `SELECT *`.

**Why projection matters:**
- Rather than showing all the fields of a document, we can choose whatever we want to show.
- It will also help us to reduce the bandwidth usage as the server will not send all the elements.

**How it works:**
- `1` means **include** this field
- `0` means **exclude** this field  
- You cannot mix include and exclude (except for `_id`)
- `_id` is **always included by default** — you must explicitly exclude it with `_id: 0`

- To get all the student's `name` with `age` equals `24`: 
```js
db.products.find({age: 24}, {name: 1})
```
- By default, `_id` is set to 1, so if we want to remove it as well, we have to use this type of query:
```js
db.products.find({age: 24}, {name: 1, _id: 0})
```

```js
// Include only name and email (plus _id by default)
db.users.find({}, {name: 1, email: 1})

// Include name, exclude _id
db.users.find({}, {name: 1, _id: 0})

// Exclude large fields (return everything EXCEPT comments and logs)
db.posts.find({}, {comments: 0, logs: 0})

// Project nested fields
db.users.find({}, {"address.city": 1, name: 1})

// Array projection with $slice (first 5 comments)
db.posts.find({}, {comments: {$slice: 5}})

// Array projection with $elemMatch (only matching array element)
db.products.find(
    {tags: "electronics"},
    {tags: {$elemMatch: {$eq: "electronics"}}}
)
```

- One Document can hold a maximum of 100 levels of nesting.
