## Introduction

**Update operations** modify existing documents in a MongoDB collection. Unlike SQL `UPDATE` which directly sets column values, MongoDB uses **update operators** (`$set`, `$inc`, `$push`, etc.) to precisely control what changes.

```
Update Operation Flow:

  db.collection.updateOne(filter, update, options)
       │              │         │         │
       │              │         │         └── {upsert, writeConcern, arrayFilters}
       │              │         └──────────── {$set: {...}, $inc: {...}, ...}
       │              └────────────────────── Which document(s) to match
       ↓
  ┌──────────────────────────────────────┐
  │ 1. Find matching document(s)         │
  │ 2. Apply update operators            │
  │ 3. Validate constraints/schema       │
  │ 4. Write changes (atomic per doc)    │
  │ 5. Update indexes if needed          │
  │ 6. Return {matchedCount, modifiedCount}│
  └──────────────────────────────────────┘
```

**Update Methods:**

| Method | Behavior |
|--------|----------|
| `updateOne()` | Updates the **first** document matching the filter |
| `updateMany()` | Updates **all** documents matching the filter |
| `replaceOne()` | Replaces the **entire document** body (except `_id`) |
| `findOneAndUpdate()` | Updates one document and returns it (before or after) |

**Key distinction**: `updateOne/Many` uses operators to modify specific fields. `replaceOne` replaces the whole document — if you forget a field, it's gone.

---

In the Users db Info collection all the documents in the following type

```js
{
  "_id": {
    "$oid": "62ac4ff719cc703713ba43c0"
  },
  "name": "Max",
  "hobbies": [
    {
      "title": "Sports",
      "frequency": 3
    },
    {
      "title": "Cooking",
      "frequency": 6
    }
  ],
  "phone": 131782734
}
```
But the object with name chris has the different type of `hobbies` array

So, we need to update the `hobbies`. We have two methods for update any object `updateOne` and `updateMany`. The names are self-explanatory.

The `update` method takes two mandatory input one is `filter` for search and `what to update`.

`$set` keyword is used to set the change the field value. Other fields will be untouched.

```js
> db.infos.updateOne(
    {"name" : "Chris"},
    { $set: 
        {"hobbies": [
            {title:"Sports",frequency:5},
            {title:"Cooking",frequency:3},
            {title:"Hiking",frequency:1}
        ]}
    }
)
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 } 

## If I again run the same query then the modifiedCount will be 0
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 0 }
```

We can update multiple documents at the same time
```js
> db.infos.updateMany(
    {"hobbies.title": "Sports"},
    {$set: {isSporty: true}}
)
{ "acknowledged" : true, "matchedCount" : 3, "modifiedCount" : 3 }
```
With `$set` operator we can change more than one field at a time as well.

We also have incrementor or decrement operator as these two are very common operation.
```js
> db.infos.updateOne(
    {name: "Manuel"}, 
    { $inc : { age : 1 }}
)
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }
```

With `$inc` we can also decrement.
```js
> db.infos.updateOne(
    { name: "Manuel" } , 
    { 
        $inc : { age :  -1 } , 
        $set : { isSporty : false }
    }
)
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }
```
We can operate on different field on the same time, but we cannot set age and increment age at the same time.

We have other 3 operators like `$inc`. those are `$min`, `$max`, `$mul`.

The field age will be updated as the max value between what we have passed and what is the previous value. If the previous value is 20 then the new value of age will be 31 but if its already 35 then the value will not be changed.
```js
db.infos.updateOne(
    { name : "Manual" },
    { $max :{ age : 31 }}
)
```

`$min` and `$max` is quite similar operation just that one is taking minimum value and another is taking maximum value.
The `$mul` operator will multiply the field with the value that we have passed.
If the previous value of age is 30 then the new value will be 30*1.1 = 33
```js
db.infos.updateOne(
    { name : "Manual" },
    { $mul :{ age : 1.1 }}
)
```

We can also drop any field with `$unset` operator.
With this command we can remove the phone field. The value of phone here will be ignored. We can assign any value.
```js
db.infos.updateOne(
    { name : "Manuel" },
    { $unset :{ phone : "" }}
)
```

We also can rename the field using the `$rename` operator.
The field age will now be converted to `totalAge`
```js
db.infos.updateMany(
    {},
    { $rename :{ age : "totalAge" }}
)

{ "acknowledged" : true, "matchedCount" : 4, "modifiedCount" : 2 }
```

We can do `update` and `insert` operation at the same time, and it is called `upsert`. 
Suppose we don’t know we have a document with name as `Abhishek` or not and we also want to change its value if it is there. 
So, we can use `upsert` here.
So, to use `upsert` we must pass the `upsert` value in the last parameter. 
By default, its value is true.
```js
> db.infos.updateOne(
    { name : "Abhishek" }, 
    { $set : 
        { 
            "hobbies": [
            { "title": "Sports", "frequency": 3 },
            { "title": "Cooking", "frequency": 6 }], 
            "phone": 131782734, 
            "isSporty": true 
        }
    } , 
    { upsert : true }
)


{
        "acknowledged" : true,
        "matchedCount" : 0,
        "modifiedCount" : 0,
        "upsertedId" : ObjectId("62da1c2f60336bad54ef7227")
}
```
MongoDB is smart enough to determine that if we are querying with equality operator then the name value must be there. 
So, in the new object name, hobbies, phone, isSporty all these values will be present.


Array update operations:

Suppose we have to find the documents where `hobbies` array has `title` value of `Sports` and `frequency` value greater than 3. 
Then the query will be like.
```js
db.infos.find({ 
    hobbies : { 
        $elemMatch : { 
            title : "Sports" , 
            "frequency" : { $gte : 3}
            }
        }
    }
)
{ 
    "_id" : ObjectId("62ac4ff719cc703713ba43be"), 
    "name" : "Chris", 
    "hobbies" : [ 
        { "title" : "Sports", "frequency" : 5 }, 
        { "title" : "Cooking", "frequency" : 3 }, 
        { "title" : "Hiking", "frequency" : 1 } 
    ], 
    "isSporty" : true 
}
{ 
    "_id" : ObjectId("62ac4ff719cc703713ba43c0"), 
    "name" : "Max", 
    "hobbies" : [ 
        { "title" : "Sports", "frequency" : 3 }, 
        { "title" : "Cooking", "frequency" : 6 } 
    ], 
    "phone" : 131782734,
    "isSporty" : true 
}
{ 
    "_id" : ObjectId("62da1c2f60336bad54ef7227"), 
    "name" : "Abhishek", 
    "hobbies" : [ 
        { "title" : "Sports", "frequency" : 3 }, 
        { "title" : "Cooking", "frequency" : 6 } 
    ],
    "isSporty" : true, 
    "phone" : 131782734 
}
```

Suppose we want to update the inner array document that we have found and highlighted above.
```js
> db.infos.updateMany({ 
    hobbies : {
        $elemMatch : { 
            title : "Sports" , 
            "frequency" : { $gte : 3}
        }
    }}, 
    { $set : { 
        "hobbies.$.highFrequency" : true 
    }}
)
{ "acknowledged" : true, "matchedCount" : 3, "modifiedCount" : 3 }
```
This `$` represents the same element. 
Here we are adding new field that is why we are using `"hobbies.$.highFrequency"` but if we want to override that document then we can simply do this `"hobbies.$" : {"title" : "Sports", "frequency" : 5}`

Suppose we want to update all the documents of the array. So, we can use $[] operator it means all the array documents.
`goodHobby` field added for all the inner array documents.
```js
> db.infos.updateMany({ 
    hobbies : { 
        $elemMatch : { title : "Sports" , "frequency" : { $gte : 3}}
    }}, 
    { $set : { "hobbies.$[].goodHobby" : true }}
)
{ "acknowledged" : true, "matchedCount" : 3, "modifiedCount" : 3 }
> db.infos.find({ 
        hobbies : { 
            $elemMatch : { title : "Sports" , "frequency" : { $gte : 3}}
        }}
    ).pretty()
{
        "_id" : ObjectId("62ac4ff719cc703713ba43be"),
        "name" : "Chris",
        "hobbies" : [
                {
                        "title" : "Sports",
                        "frequency" : 5,
                        "highFrequency" : true,
                        "goodHobby" : true
                },
                {
                        "title" : "Cooking",
                        "frequency" : 3,
                        "goodHobby" : true
                },
                {
                        "title" : "Hiking",
                        "frequency" : 1,
                        "goodHobby" : true
                }
        ],
        "isSporty" : true
}
```

Let's say if we have a criterion to upadate only some certain documents then we can `$[ el ]` and later we will define the `el` condition in the thir parameter `arrayFilers` part.
In array filter we can pass as many conditions as we want.
```js
> db.infos.updateOne(
    { name: "Abhishek"}, 
    { $set : { "hobbies.$[el].goodFrequency" : true}} , 
    { arrayFilters : [{ "el.frequency" :{ $gte : 3}} ]} 
)
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }

> db.infos.find({name:"Abhishek"})
{ 
    "_id" : ObjectId("62da1c2f60336bad54ef7227"), 
    "name" : "Abhishek", 
    "hobbies" : [ 
        { "title" : "Sports", "frequency" : 3, "highFrequency" : true, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "Cooking", "frequency" : 6, "goodHobby" : true, "goodFrequency" : true } 
    ], 
    "isSporty" : true, 
    "phone" : 131782734 
}
```

We can also add new element in our array. With `$push` we can add new element to the existing array.
```js
> db.infos.updateOne(
    { name: "Abhishek"}, 
    { $push : 
        { hobbies : { title: "Hiking" , frequency : 1}}
    } 
)
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }

> db.infos.find({name:"Abhishek"})
{ 
    "_id" : ObjectId("62da1c2f60336bad54ef7227"), 
    "name" : "Abhishek", 
    "hobbies" : [ 
        { "title" : "Sports", "frequency" : 3, "highFrequency" : true, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "Cooking", "frequency" : 6, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "Hiking", "frequency" : 1 } 
    ], 
    "isSporty" : true, 
    "phone" : 131782734 
}
```

We can also add more than one documents with `$each` operator.
```js
> db.infos.updateOne(
    { name: "Abhishek"}, 
    { $push : { 
        hobbies : { 
            $each : [
                { title: "Hiking" , frequency : 1},
                { title : "wine", frequecy: 1}
            ]
        }}
    }
)
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }

> db.infos.find({name:"Abhishek"})
{ 
    "_id" : ObjectId("62da1c2f60336bad54ef7227"), 
    "name" : "Abhishek", 
    "hobbies" : [ 
        { "title" : "Sports", "frequency" : 3, "highFrequency" : true, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "Cooking", "frequency" : 6, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "Hiking", "frequency" : 1 }, 
        { "title" : "Hiking", "frequency" : 1 }, 
        { "title" : "wine", "frequecy" : 1 } 
    ], 
    "isSporty" : true, 
    "phone" : 131782734 
}
```
We can also add `sor`t or `slice` operator to `add` the element in sorted order or we can also take only one element.

But there is issue with `$push` operator. 
If the values are already existing, then also it will add the value. 
We can use `$addToSet` operator for to add `unique` element in the array.
```js
> db.infos.updateOne(
    { name: "Abhishek"}, 
    { $addToSet : { 
        hobbies : { 
            $each : [
                { title: "Hiking" , frequency : 1},
                {title : "wine", frequecy: 1}
            ]
        }}
    }
)
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 0 }

> db.infos.find({name:"Abhishek"})
{ 
    "_id" : ObjectId("62da1c2f60336bad54ef7227"), 
    "name" : "Abhishek", 
    "hobbies" : [ 
        { "title" : "Sports", "frequency" : 3, "highFrequency" : true, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "Cooking", "frequency" : 6, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "Hiking", "frequency" : 1 }, 
        { "title" : "Hiking", "frequency" : 1 }, 
        { "title" : "wine", "frequecy" : 1 } 
    ], 
    "isSporty" : true, 
    "phone" : 131782734 
}

We can also pull the element from an array with `$pull` operator.
```js
> db.infos.updateOne(
        { name: "Abhishek"},
        { $pull : { hobbies : { title : "Hiking" }}}
    )
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }

> db.infos.find({name:"Abhishek"})
{ 
    "_id" : ObjectId("62da1c2f60336bad54ef7227"), 
    "name" : "Abhishek", 
    "hobbies" : [ 
        { "title" : "Sports", "frequency" : 3, "highFrequency" : true, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "Cooking", "frequency" : 6, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "wine", "frequecy" : 1 } 
    ], 
    "isSporty" : true, 
    "phone" : 131782734 
}
```
`{ $pull : { hobbies : { title : "Hiking" }}}` it means pull from the hobbies array where title is Hiking. We can also add other queries.

If we want to remove the last element from the array, then we can use `$pop` operator with value of 1 and if we want to remove the first element then we can assign the value with -1.
```js
> db.infos.find({name:"Abhishek"})
{ 
    "_id" : ObjectId("62da1c2f60336bad54ef7227"), 
    "name" : "Abhishek", 
    "hobbies" : [ 
        { "title" : "Sports", "frequency" : 3, "highFrequency" : true, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "Cooking", "frequency" : 6, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "wine", "frequecy" : 1 } 
    ], 
    "isSporty" : true, 
    "phone" : 131782734 
}

> db.infos.updateOne(
        { name: "Abhishek"}, 
        { $pop : { hobbies : 1}}
    )
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }

> db.infos.find({name:"Abhishek"})
{ 
    "_id" : ObjectId("62da1c2f60336bad54ef7227"), 
    "name" : "Abhishek", 
    "hobbies" : [ 
        { "title" : "Sports", "frequency" : 3, "highFrequency" : true, "goodHobby" : true, "goodFrequency" : true }, 
        { "title" : "Cooking", "frequency" : 6, "goodHobby" : true, "goodFrequency" : true } 
    ], 
    "isSporty" : true, 
    "phone" : 131782734 
}

> db.infos.updateOne(
        { name: "Abhishek"}, 
        { $pop : { hobbies : -1}}
    )
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }

> db.infos.find({name:"Abhishek"})
{ 
    "_id" : ObjectId("62da1c2f60336bad54ef7227"), 
    "name" : "Abhishek", 
    "hobbies" : [ 
        { "title" : "Cooking", "frequency" : 6, "goodHobby" : true, "goodFrequency" : true } 
    ], 
    "isSporty" : true, 
    "phone" : 131782734 
}
```



## More examples

### Basic Updates

**Intent**: These are the most common field-level update operations — set values, remove fields, rename, increment counters, and track timestamps.

```js
db.coll.updateOne({"_id": 1}, {$set: {"year": 2016, name: "Max"}})
db.coll.updateOne({"_id": 1}, {$unset: {"year": 1}})
db.coll.updateOne({"_id": 1}, {$rename: {"year": "date"} })
db.coll.updateOne({"_id": 1}, {$inc: {"year": 5}})
db.coll.updateOne({"_id": 1}, {$mul: {price: NumberDecimal("1.25"), qty: 2}})
db.coll.updateOne({"_id": 1}, {$min: {"imdb": 5}})
db.coll.updateOne({"_id": 1}, {$max: {"imdb": 8}})
db.coll.updateOne({"_id": 1}, {$currentDate: {"lastModified": true}})
db.coll.updateOne({"_id": 1}, {$currentDate: {"lastModified": {$type: "timestamp"}}})
```

### Array Updates

**Intent**: These operators modify array fields — add elements, remove elements, update specific elements by position or condition.

```js
db.coll.updateOne({"_id": 1}, {$push :{"array": 1}})
db.coll.updateOne({"_id": 1}, {$pull :{"array": 1}})
db.coll.updateOne({"_id": 1}, {$addToSet :{"array": 2}})
db.coll.updateOne({"_id": 1}, {$pop: {"array": 1}})  // last element
db.coll.updateOne({"_id": 1}, {$pop: {"array": -1}}) // first element
db.coll.updateOne({"_id": 1}, {$pullAll: {"array" :[3, 4, 5]}})
db.coll.updateOne({"_id": 1}, {$push: {"scores": {$each: [90, 92]}}})
db.coll.updateOne({"_id": 2}, {$push: {"scores": {$each: [40, 60], $sort: 1}}}) // array sorted
db.coll.updateOne({"_id": 1, "grades": 80}, {$set: {"grades.$": 82}})
db.coll.updateMany({}, {$inc: {"grades.$[]": 10}})
db.coll.updateMany({}, {$set: {"grades.$[element]": 100}}, {multi: true, arrayFilters: [{"element": {$gte: 100}}]})
```

**Array Update Operators Summary:**

| Operator | Action | Duplicates Allowed? |
|----------|--------|:---:|
| `$push` | Append element to array | Yes |
| `$addToSet` | Append only if not exists | No (set semantics) |
| `$pull` | Remove all matching elements | N/A |
| `$pullAll` | Remove specific values | N/A |
| `$pop` | Remove first (`-1`) or last (`1`) element | N/A |
| `$each` | Used with `$push`/`$addToSet` to add multiple | Depends on parent |
| `$sort` | Used with `$push` + `$each` to maintain order | N/A |
| `$slice` | Used with `$push` + `$each` to cap array size | N/A |

### FindOneAndUpdate

**Intent**: Atomically finds a document, updates it, and returns either the original or updated document. Useful for implementing atomic counters, queue-like processing, or when you need the document value.

```js
db.coll.findOneAndUpdate({"name": "Max"}, {$inc: {"points": 5}}, {returnNewDocument: true})
```

```js
// Atomic counter — increment and return the new value
db.counters.findOneAndUpdate(
    { _id: "orderId" },
    { $inc: { seq: 1 } },
    { returnNewDocument: true, upsert: true }
)
// Returns: { _id: "orderId", seq: 43 } (the new value)

// Queue pattern — claim the next unprocessed job
db.jobs.findOneAndUpdate(
    { status: "pending" },
    { $set: { status: "processing", worker: "worker-1", startedAt: new Date() } },
    { sort: { priority: -1, createdAt: 1 }, returnNewDocument: true }
)
```

### Upsert

**Intent**: Update if exists, insert if not. Combines update + insert in a single atomic operation. The `$setOnInsert` operator sets fields **only when inserting** (not when updating an existing document).

```js
db.coll.updateOne({"_id": 1}, {$set: {item: "apple"}, $setOnInsert: {defaultQty: 100}}, {upsert: true})
```

```js
// Track daily page views — create if first visit, increment if exists
db.pageViews.updateOne(
    { page: "/home", date: "2024-06-15" },
    {
        $inc: { views: 1 },
        $setOnInsert: { page: "/home", date: "2024-06-15", firstViewAt: new Date() }
    },
    { upsert: true }
)
```

### Replace

**Intent**: Replace the entire document body (except `_id`). Use when you want to overwrite a document completely rather than modifying individual fields. **Any fields not in the replacement document will be removed.**

```js
db.coll.replaceOne({"name": "Max"}, {"firstname": "Maxime", "surname": "Beugnet"})
```

### Write Concern
```js
db.coll.updateMany({}, {$set: {"x": 1}}, {"writeConcern": {"w": "majority", "wtimeout": 5000}})
```