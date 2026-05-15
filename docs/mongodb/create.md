## General

**Insert operations** add new documents to a MongoDB collection. If the collection does not exist, MongoDB creates it automatically on the first insert.

```
Insert Flow:

  Application
       │
       ↓
  ┌─────────────────────────────────────┐
  │          Insert Operation            │
  │                                     │
  │  1. Validate document against       │
  │     schema (if validator exists)    │
  │  2. Generate _id (if not provided)  │
  │  3. Write to oplog (replica sets)   │
  │  4. Write to collection             │
  │  5. Return acknowledgment           │
  └─────────────────────────────────────┘
```

**We have three methods for inserting documents**

- `insertOne` — Insert a single document. Returns `{ acknowledged, insertedId }`.
- `insertMany` — Insert an array of documents. Returns `{ acknowledged, insertedIds }`.
- `insert` — Can handle single or multiple documents (legacy).

Though `insert` method is flexible enough to handle one document or multiple but still it is deprecated on purpose.

Also, we can directly import from a json file using mongoimort command

---

### Ordered vs Unordered Inserts

**Intent**: When inserting multiple documents, the `ordered` option controls whether MongoDB stops on the first error or continues inserting the remaining valid documents.

If we are using insert many and we are inserting multiple documents in a shot then if there is a issue with any document in that list then from that onwards there will be no insertions, only the documents before the wrecked document will be inserted, it will not be rolled back.

Like for the following code there is a issue in third document
```js
> db.hobbies.insertMany([{_id: "yoga"}, {_id: "sports"} ,{_id: "yoga"}, {_id: "maths"}])
"errmsg" : "E11000 duplicate key error collection: contacts.hobbies index: _id_ dup key: { _id: \"yoga\" }",

> db.hobbies.find().toArray()
[ { "_id" : "yoga" }, { "_id" : "sports" } ]
```

But to remove this one we can pass one argument {ordered: false}. By default, it is true. It defines that the insertion will be ordered or not.

If we again try to run the previous code in shell it will again give us the error, but it will not stop to the error document rather it will insert all the correct documents.
```js
> db.hobbies.insertMany([{_id: "yoga"}, {_id: "sports"}, {_id: "yoga"}, {_id: "maths"}], {ordered: false})
"E11000 duplicate key error collection: contacts.hobbies index: _id_ dup key: { _id: \"yoga\" }", "E11000 duplicate key error collection: contacts.hobbies index: _id_ dup key: { _id: \"sports\" }",

> db.hobbies.find().toArray()
[ { "_id" : "yoga" }, { "_id" : "sports" }, { "_id" : "maths" } ]
```

**Summary:**

| Mode | Behavior on Error | Use When |
|------|-------------------|----------|
| `ordered: true` (default) | Stops at first error, documents before it are inserted | Order matters, prefer consistency |
| `ordered: false` | Continues past errors, inserts all valid documents | Bulk loading, duplicate handling |

---

### insertOne and insertMany Examples

Example of `insertOne` and `insertMany`
```js
> use contacts
switched to db contacts

> db.persons.insertOne({name:"Abhishek Ghosh"})
{
        "acknowledged" : true,
        "insertedId" : ObjectId("62aadb4256184ff0056adbd7")
}

> db.persons.insertMany([{name:"Abhishek Pal"},{name:"Bishal Mukherjee"}])
{
        "acknowledged" : true,
        "insertedIds" : [
                ObjectId("62aadbed56184ff0056adbd8"),
                ObjectId("62aadbed56184ff0056adbd9")
        ]
}
```

---

### The _id Field

Every document in MongoDB **must have an `_id` field** that serves as the primary key. If you don't provide one, MongoDB auto-generates an `ObjectId`.

```js
// Auto-generated _id (ObjectId)
db.users.insertOne({ name: "Alice" })
// Result: { _id: ObjectId("64a1b2c3..."), name: "Alice" }

// Custom _id (any unique value)
db.users.insertOne({ _id: "user-001", name: "Bob" })
// Result: { _id: "user-001", name: "Bob" }

// Custom numeric _id
db.counters.insertOne({ _id: 1, count: 0 })
```

**ObjectId structure (12 bytes):**
```
ObjectId("507f1f77bcf86cd799439011")
         ├──────┤├──┤├──┤├────┤
         │       │    │    └── 3 bytes: counter (auto-incrementing)
         │       │    └─────── 2 bytes: process ID
         │       └──────────── 5 bytes: random value
         └──────────────────── 4 bytes: Unix timestamp (seconds)

// Extract timestamp from ObjectId:
ObjectId("507f1f77bcf86cd799439011").getTimestamp()
// ISODate("2012-10-17T20:46:31Z")
```

---

## WriteConcern

### Description

Write concern describes the level of acknowledgment requested from MongoDB for write operations to a standalone mongod or to replica sets or to sharded clusters. In sharded clusters, mongos instances will pass the write concern on to the shards.

the write concern is a specification of MongoDB for write operations that determines the acknowledgement you want after a write operation has taken place. MongoDB has a default write concern of always acknowledging all writes, which means that after every write, MongoDB must always return an acknowledgement (in a form of a document), meaning that it was successful. When asking for write acknowledgement, if none isn't returned (in case of failover, crashes), the write isn't successful. This behavior is very useful specially on replica set usage, since you will have more than one mongod instance, and depending on your needs, maybe you don't want all instances to acknowledge the write, just a few, to speed up writes. Also, when to specify a write concern, you can specify journal writing, so you can guarantee that operation result and any rollbacks required if a failover happens. More information, here.

In your case, it depends on how many mongod (if you have replica sets or just a single server) instances you have. Since "always acknowledge" is the default, you may want to change it if you have to manage replica sets operations and speed things up or just doesn't care about write acknowledgement in a single instance (which is not so good, since it's a single server only).

Write concern can include the following fields: `{w: <value>, j: <boolean>, wtimeout: <number>}`
```
{w: 1, j: true, wtimeout: 500}
```

the `w` option to request acknowledgment that the write operation has propagated to a specified number of mongod instances or to mongod instances with specified tags.

the `j` option to request acknowledgment that the write operation has been written to the on-disk journal.

the `wtimeout` option to specify a time limit to prevent write operations from blocking indefinitely.

**Write Concern Visualization:**

```
Write Concern: { w: "majority", j: true }

  Application
       │
       │  insertOne({...})
       ↓
  ┌──────────┐     Write to journal
  │ PRIMARY   │─────────────────────→ Journal on disk ✅
  └─────┬─────┘
        │  Replicate via oplog
   ┌────┴────┐
   ↓         ↓
┌──────┐ ┌──────┐
│SEC-1 │ │SEC-2 │
│  ✅  │ │ ...  │    ← Majority (2 of 3) acknowledged
└──────┘ └──────┘

Application receives acknowledgment only after:
  1. Primary has written to journal (j: true)
  2. Majority of replica set members have acknowledged (w: "majority")
```

### Write Concern Levels
MongoDB has the following levels of conceptual write concern, listed from weakest to strongest:

#### Unacknowledged
With an `unacknowledged` write concern, MongoDB does not acknowledge the receipt of write operations. `unacknowledged` is like errors ignored; however, drivers will attempt to receive and handle network errors when possible. The driver's ability to detect network errors depends on the system's networking configuration.
Write operation to a `mongod` instance with write concern of `unacknowledged`. The client does not wait for any acknowledgment. 

#### Acknowledged
With a receipt acknowledged write concern, the mongod confirms the receipt of the write operation. Acknowledged write concern allows clients to catch network, duplicate key, and other errors. This is default write concern.
Write operation to a `mongod` instance with write concern of `acknowledged`. The client waits for acknowledgment of success or exception.

#### Journaled
With a journaled write concern, the MongoDB acknowledges the write operation only after committing the data to the journal. This write concern ensures that MongoDB can recover the data following a shutdown or power interruption.
You must have journaling enabled to use this write concern.
Write operation to a `mongod` instance with write concern of `journaled`. The `mongod` sends acknowledgment after it commits the write operation to the journal.

#### Replica Acknowledged
Replica sets present additional considerations with regards to write concern. The default write concern only requires acknowledgement from the primary. With `replica acknowledged` write concern, you can guarantee that the write operation propagates to additional members of the replica set.
Write operation to a replica set with write concern level of `w:2` or write to the primary and at least one secondary.

### Reference 
- [Write Concern](https://www.mongodb.com/docs/manual/reference/write-concern/)
- [Journaling](https://www.mongodb.com/docs/manual/core/journaling/)

When we have millions of records inserting in seconds then on that time, we can skip the acknowledgement and use `w: 0`. By default is `undefined`.

If `j: true`, then inserting will take some extra time as it will write on journal. By default, is `undefined`. Here it has the higher security.

## Atomicity
It means when we are inserting any document then either it will be saved as a whole, or it will not be saved at all if there is any issue. MongoDB provides atomic transaction guarantee.

## Import from file

Lastly, we can import json file in and save it mongodb.

if it is a single document
```
mongoimport --db dbName --collection collectionName --file /path/fileName.json
```

if it is a array of documents.
```
mongoimport --db dbName --collection collectionName --file /path/fileName.json --jsonArray
```

if we add `--drop` then it will delete previous data  





## More examples

**Insert one document:**
```js
db.coll.insertOne({name: "Max"})
```

**Insert many documents (ordered bulk insert):**
```js
db.coll.insertMany([{name: "Max"}, {name:"Alex"}])
```

**Insert many documents (unordered bulk insert):**
```js
db.coll.insertMany([{name: "Max"}, {name:"Alex"}], {ordered: false})
```

**Insert a document with the current date:**
```js
db.coll.insertOne({date: ISODate()})
```

**Insert a document with write concern:**
```js
db.coll.insertOne({name: "Max"}, {"writeConcern": {"w": "majority", "wtimeout": 5000}})
```