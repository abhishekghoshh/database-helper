## Introduction

**Delete operations** permanently remove documents from a collection. Unlike SQL databases that support `TRUNCATE` vs `DELETE`, MongoDB has a single mechanism — once deleted, the data is gone (unless you have a backup or replica).

**Key Concepts:**
- Delete operations are **atomic at the single-document level** — each document is fully removed or not at all
- `deleteOne()` removes the **first document** matching the filter (based on natural order or index order)
- `deleteMany()` removes **all documents** matching the filter
- `findOneAndDelete()` returns the deleted document — useful when you need the data before removing it
- Empty filter `{}` matches **all documents** — use with extreme caution

```
Delete Decision Flow:

  Need to remove documents?
       │
       ├── Remove ONE specific document? → deleteOne({_id: ObjectId(...)})
       │
       ├── Remove MANY matching documents? → deleteMany({filter})
       │
       ├── Need the document data BEFORE deleting? → findOneAndDelete({filter})
       │
       ├── Remove ALL documents (keep collection)? → deleteMany({})
       │
       └── Remove entire collection (including indexes)? → db.coll.drop()
```

**Soft Delete Pattern:**
MongoDB has no built-in soft delete. If you need to "delete" without losing data, use a flag:
```js
// Soft delete — mark as deleted instead of removing
db.users.updateOne(
    { _id: userId },
    { $set: { deleted: true, deletedAt: new Date() } }
)

// Query only active (non-deleted) documents
db.users.find({ deleted: { $ne: true } })
```

---

To `delete` any document, we have `deleteOne` and `deleteMany` methods. 
In the `2nd` parameter we can also give `writeConcerns`. 

delete the first record where name is `Abhishek`
```js
db.infos.deleteOne({ name :  "Abhishek" })
```

delete the all record where age is greater than equal to `40`
```js
db.infos.deleteMany({ age :  { $gte : 40} })
```

delete the all record where age don't exists
```js
db.infos.deleteMany({ age :  { $exists : false } })
```


We can `delete` all the documents in a collection by using `db.infos.deleteMany({})`

We can `drop` the collection by `db.infos.drop()`

We can `drop` the database by `db.dropDatabase()`

---

### Delete vs Drop — What's the Difference?

| Operation | What it Does | Indexes Kept? | Use When |
|-----------|-------------|:---:|----------|
| `deleteMany({})` | Removes all documents | ✅ Yes | Clear data but keep collection structure |
| `db.coll.drop()` | Removes collection entirely | ❌ No | Remove collection + all indexes |
| `db.dropDatabase()` | Removes entire database | ❌ No | Remove everything (development cleanup) |

---

### Bulk Delete with Filters

```js
// Delete all inactive users who haven't logged in for 2 years
db.users.deleteMany({
    status: "inactive",
    lastLogin: { $lt: ISODate("2022-01-01") }
})

// Delete documents matching complex conditions
db.logs.deleteMany({
    $or: [
        { level: "debug" },
        { timestamp: { $lt: ISODate("2023-01-01") } }
    ]
})

// Delete using array conditions
db.users.deleteMany({ roles: { $size: 0 } })  // Users with no roles
```

---

## More Examples

**Delete one document:**
```js
db.coll.deleteOne({name: "Max"})
```

**Delete many documents with write concern:**
```js
db.coll.deleteMany({name: "Max"}, {"writeConcern": {"w": "majority", "wtimeout": 5000}})
```

**Delete all documents in a collection:**
```js
db.coll.deleteMany({}) // WARNING! Deletes all the docs but not the collection itself and its index definitions
```

**Find one document and delete:**
```js
db.coll.findOneAndDelete({"name": "Max"})
```

**findOneAndDelete with sort — delete the oldest document:**
```js
// Delete the oldest pending order and return it
db.orders.findOneAndDelete(
    { status: "pending" },
    { sort: { createdAt: 1 } }  // Sort ascending = oldest first
)
// Returns the deleted document (useful for queue-like processing)
```

**Delete with a TTL index (automatic deletion):**
```js
// Instead of manual deletion, let MongoDB auto-delete expired documents
db.sessions.createIndex({ "expiresAt": 1 }, { expireAfterSeconds: 0 })
// Documents are automatically deleted when expiresAt < current time
// MongoDB checks every ~60 seconds
```