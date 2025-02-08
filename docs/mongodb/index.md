## Introduction

Why Indexes?

An index can speed up our find update and delete query. If our query is like `db.products.find({ seller : “Max” })` then MongoDB will search for the entire collection for the seller name `“Max”`, which is also called as `COLLSCAN` and this can take a while if there is million record. 

So, in that case we can create a `Index` on `Selle`r field. MongoDB will create an `Ordered` list with all the values of the `Seller`s and all the items of this list will have a pointer to the actual document in the collection. 
Now if we run the exact query then Mongodb will see that there is an `Index` on Seller so MongoDB will run `IXSCAN` and directly jump to `“M”` which will speed up the querying.

But we should not overdo the indexes. If we can index on all fields, then it will certainly improve the performance for the find query but for the `insert` query it will slow down. As now it will again have to update the Ordered list for every field index for every insert and update.

To see the all the index present on the collection:
```js
> db.infos.getIndexes()
[ { "v" : 2, "key" : { "_id" : 1 }, "name" : "_id_" } ]
```

By default, mongodb will create an index on `_id` field.
To create an index on specific fields:
```js
db.infos.createIndex( { “dob.age” : 1} } )

db.infos.createIndex( { “dob.age” : -1} } )
```
`1` means increasing and `-1` means decreasing Though that does not matter as mongoDB can traverse both ways. 

We can also create index with more than on field. The order matters here.
```js
db.infos.createIndex( { “email” : 1, “dob.age” : 1} } )
```
This means that mongoDb will create a `compound index` and first the `index` with email then `dob.age`
Example: (a@test.com,23) will come before (a.@test.com,24) 

To drop the index use:
```js
>db.infos.dropIndex({ "dob.age": 1 })
{ "nIndexesWas" : 2, "ok" : 1 }
```

We can also drop index by name. 
```js
> db.infos.dropIndex("dob.age_1")
{ "nIndexesWas" : 2, "ok" : 1 }
```


## Query Explain

To analyse how a query will execute mongodb has a unique method that is explain().
```js
> db.infos.explain().find( { "dob.age" : { $gt : 60 }} )
{
        "explainVersion" : "1",
        "queryPlanner" : {
                "namespace" : "persons.infos",
                "indexFilterSet" : false,
                "parsedQuery" : {
                        "dob.age" : {
                                "$gt" : 60
                        }
                },
                "queryHash" : "FC9E47D2",
                "planCacheKey" : "A5FF588D",
                "maxIndexedOrSolutionsReached" : false,
                "maxIndexedAndSolutionsReached" : false,
                "maxScansToExplodeReached" : false,
                "winningPlan" : {
                        "stage" : "COLLSCAN",
                        "filter" : {
                                "dob.age" : {
                                        "$gt" : 60
                                }
                        },
                        "direction" : "forward"
                },
                "rejectedPlans" : [ ]
        },
        "command" : {
                "find" : "infos",
                "filter" : {
                        "dob.age" : {
                                "$gt" : 60
                        }
                },
                "$db" : "persons"
        },
        
        "ok" : 1
}
```

In the winning plan we can see `COLLSCAN` as mongodb searched the entire collection for this query.
There is also a rejected plans array but currently it is empty as mongodb has no other option than searching the entire array.

We can also add additional properties in explain(). It will print some additional information
```js
> db.infos.explain("executionStats").find( { "dob.age" : { $gt : 60 }} )
{
        "explainVersion" : "1",
        "queryPlanner" : {
                "namespace" : "persons.infos",
                "indexFilterSet" : false,
                "parsedQuery" : {
                        "dob.age" : {
                                "$gt" : 60
                        }
                },
                "maxIndexedOrSolutionsReached" : false,
                "maxIndexedAndSolutionsReached" : false,
                "maxScansToExplodeReached" : false,
                "winningPlan" : {
                        "stage" : "COLLSCAN",
                        "filter" : {
                                "dob.age" : {
                                        "$gt" : 60
                                }
                        },
                        "direction" : "forward"
                },
                "rejectedPlans" : [ ]
        },
        "executionStats" : {
                "executionSuccess" : true,
                "nReturned" : 1222,
                "executionTimeMillis" : 3,
                "totalKeysExamined" : 0,
                "totalDocsExamined" : 5000,
                "executionStages" : {
                        "stage" : "COLLSCAN",
                        "filter" : {
                                "dob.age" : {
                                        "$gt" : 60
                                }
                        },
                        "nReturned" : 1222,
                        "executionTimeMillisEstimate" : 0,
                        "works" : 5002,
                        "advanced" : 1222,
                        "needTime" : 3779,
                        "needYield" : 0,
                        "saveState" : 5,
                        "restoreState" : 5,
                        "isEOF" : 1,
                        "direction" : "forward",
                        "docsExamined" : 5000
                }
        },
        "command" : {
                "find" : "infos",
                "filter" : {
                        "dob.age" : {
                                "$gt" : 60
                        }
                },
                "$db" : "persons"
        },
        
        "ok" : 1
}
```

Here we can see some other additional informations like totalDocumentScan, totalDocumentReturn, executionTimeMillis.

Now if we do the indexing on dob.age and run the same query with explain
```js
> db.infos.createIndex( { "dob.age" : 1} )
{
        "numIndexesBefore" : 1,
        "numIndexesAfter" : 2,
        "createdCollectionAutomatically" : false,
        "ok" : 1
}

> db.infos.explain("executionStats").find( { "dob.age" : { $gt : 60 }} )
{
        "explainVersion" : "1",
        "queryPlanner" : {
                "namespace" : "persons.infos",
                "indexFilterSet" : false,
                "parsedQuery" : {
                        "dob.age" : {
                                "$gt" : 60
                        }
                },
                "maxIndexedOrSolutionsReached" : false,
                "maxIndexedAndSolutionsReached" : false,
                "maxScansToExplodeReached" : false,
                "winningPlan" : {
                        "stage" : "FETCH",
                        "inputStage" : {
                                "stage" : "IXSCAN",
                                "keyPattern" : {
                                        "dob.age" : 1
                                },
                                "indexName" : "dob.age_1",
                                "isMultiKey" : false,
                                "multiKeyPaths" : {
                                        "dob.age" : [ ]
                                },
                                "isUnique" : false,
                                "isSparse" : false,
                                "isPartial" : false,
                                "indexVersion" : 2,
                                "direction" : "forward",
                                "indexBounds" : {
                                        "dob.age" : [
                                                "(60.0, inf.0]"
                                        ]
                                }
                        }
                },
                "rejectedPlans" : [ ]
        },
        "executionStats" : {
                "executionSuccess" : true,
                "nReturned" : 1222,
                "executionTimeMillis" : 50,
                "totalKeysExamined" : 1222,
                "totalDocsExamined" : 1222,
                "executionStages" : {
                        "stage" : "FETCH",
                        "nReturned" : 1222,
                        "executionTimeMillisEstimate" : 0,
                        "works" : 1223,
                        "advanced" : 1222,
                        "needTime" : 0,
                        "needYield" : 0,
                        "saveState" : 1,
                        "restoreState" : 1,
                        "isEOF" : 1,
                        "docsExamined" : 1222,
                        "alreadyHasObj" : 0,
                        "inputStage" : {
                                "stage" : "IXSCAN",
                                "nReturned" : 1222,
                                "executionTimeMillisEstimate" : 0,
                                "works" : 1223,
                                "advanced" : 1222,
                                "needTime" : 0,
                                "needYield" : 0,
                                "saveState" : 1,
                                "restoreState" : 1,
                                "isEOF" : 1,
                                "keyPattern" : {
                                        "dob.age" : 1
                                },
                                "indexName" : "dob.age_1",
                                "isMultiKey" : false,
                                "multiKeyPaths" : {
                                        "dob.age" : [ ]
                                },
                                "isUnique" : false,
                                "isSparse" : false,
                                "isPartial" : false,
                                "indexVersion" : 2,
                                "direction" : "forward",
                                "indexBounds" : {
                                        "dob.age" : [
                                                "(60.0, inf.0]"
                                        ]
                                },
                                "keysExamined" : 1222,
                                "seeks" : 1,
                                "dupsTested" : 0,
                                "dupsDropped" : 0
                        }
                }
        },
        "command" : {
                "find" : "infos",
                "filter" : {
                        "dob.age" : {
                                "$gt" : 60
                        }
                },
                "$db" : "persons"
        },
   
        "ok" : 1
}
```
Now the query did not search for the entire collection it has done an `IXSCAN`.



## Indexes Behind the Scenes



**What does createIndex() do in detail?**

Whilst we can't really see the index, you can think of the index as a simple list of values + pointers to the original document.
Something like this (for the "age" field):

- (29, "address in memory/ collection a1")
- (30, "address in memory/ collection a2")
- (33, "address in memory/ collection a3")

The documents in the collection would be at the "addresses" a1, a2 and a3. The order does not have to match the order in the index (and most likely, it indeed won't).

The important thing is that the index items are ordered (ascending or descending - depending on how you created the index). 

`createIndex({age: 1})` creates an index with ascending sorting, `createIndex({age: -1})` creates one with descending sorting.

MongoDB is now able to quickly find a fitting document when you filter for its age as it has a sorted list. Sorted lists are way quicker to search because you can skip entire ranges (and don't have to look at every single document).

Additionally, sorting (via sort(...)) will also be sped up because you already have a sorted list. Of course, this is only true when sorting for the age.

Let’s say all our document has `age` greater than 50 and in query `[db.infos.find({"dob.age": { $gt: 20 }})]` we are trying to find the documents greater than `20` so it will return all the documents. So, in this case IXSCAN has the less performance as it will introduce an extra step. As at first the mongodb will scan the entire index then it will go to the actual mongodb collection. If we delete the index, then it will again search with COLSCAN and eventually that will have a better performance. So, it is recommended that only to use index when the query will return a `small subset` of the actual collection. 

Index on Boolean value does not make much sense.


## Compound index


first let's create a compound index
```js
> db.infos.createIndex({ "dob.age" : 1, "gender" : 1})
{
    "numIndexesBefore" : 1,
    "numIndexesAfter" : 2,
    "createdCollectionAutomatically" : false,
    "ok" : 1
}
```

If we search with dob.age and gender then mongodb will use this compound index.
```js
> db.infos.explain("executionStats").find({"dob.age" : 35, "gender" : "male"})
{
        "explainVersion" : "1",
        "queryPlanner" : {
                "namespace" : "persons.infos",
                "indexFilterSet" : false,
                "parsedQuery" : {
                        "$and" : [
                                {
                                        "dob.age" : {
                                                "$eq" : 35
                                        }
                                },
                                {
                                        "gender" : {
                                                "$eq" : "male"
                                        }
                                }
                        ]
                },
                "maxIndexedOrSolutionsReached" : false,
                "maxIndexedAndSolutionsReached" : false,
                "maxScansToExplodeReached" : false,
                "winningPlan" : {
                        "stage" : "FETCH",
                        "inputStage" : {
                                "stage" : "IXSCAN",
                                "keyPattern" : {
                                        "dob.age" : 1,
                                        "gender" : 1
                                },
                                "indexName" : "dob.age_1_gender_1",
                                "isMultiKey" : false,
                                "multiKeyPaths" : {
                                        "dob.age" : [ ],
                                        "gender" : [ ]
                                },
                                "isUnique" : false,
                                "isSparse" : false,
                                "isPartial" : false,
                                "indexVersion" : 2,
                                "direction" : "forward",
                                "indexBounds" : {
                                        "dob.age" : [
                                                "[35.0, 35.0]"
                                        ],
                                        "gender" : [
                                                "[\"male\", \"male\"]"
                                        ]
                                }
                        }
                },
                "rejectedPlans" : [ ]
        },
        "executionStats" : {
                "executionSuccess" : true,
                "nReturned" : 43,
                "executionTimeMillis" : 19,
                "totalKeysExamined" : 43,
                "totalDocsExamined" : 43,
                "executionStages" : {
                        "stage" : "FETCH",
                        "nReturned" : 43,
                        "executionTimeMillisEstimate" : 11,
                        "works" : 44,
                        "advanced" : 43,
                        "needTime" : 0,
                        "needYield" : 0,
                        "saveState" : 1,
                        "restoreState" : 1,
                        "isEOF" : 1,
                        "docsExamined" : 43,
                        "alreadyHasObj" : 0,
                        "inputStage" : {
                                "stage" : "IXSCAN",
                                "nReturned" : 43,
                                "executionTimeMillisEstimate" : 11,
                                "works" : 44,
                                "advanced" : 43,
                                "needTime" : 0,
                                "needYield" : 0,
                                "saveState" : 1,
                                "restoreState" : 1,
                                "isEOF" : 1,
                                "keyPattern" : {
                                        "dob.age" : 1,
                                        "gender" : 1
                                },
                                "indexName" : "dob.age_1_gender_1",
                                "isMultiKey" : false,
                                "multiKeyPaths" : {
                                        "dob.age" : [ ],
                                        "gender" : [ ]
                                },
                                "isUnique" : false,
                                "isSparse" : false,
                                "isPartial" : false,
                                "indexVersion" : 2,
                                "direction" : "forward",
                                "indexBounds" : {
                                        "dob.age" : [
                                                "[35.0, 35.0]"
                                        ],
                                        "gender" : [
                                                "[\"male\", \"male\"]"
                                        ]
                                },
                                "keysExamined" : 43,
                                "seeks" : 1,
                                "dupsTested" : 0,
                                "dupsDropped" : 0
                        }
                }
        },
        "command" : {
                "find" : "infos",
                "filter" : {
                        "dob.age" : 35,
                        "gender" : "male"
                },
                "$db" : "persons"
        },
}
```


If we just look for the age, then also mongodb will use this index as “dob.age” comes first in the index order.

```js
> db.infos.explain("executionStats").find({"dob.age" : 35})
{
        "explainVersion" : "1",
        "queryPlanner" : {
                "namespace" : "persons.infos",
                "indexFilterSet" : false,
                "parsedQuery" : {
                        "dob.age" : {
                                "$eq" : 35
                        }
                },
                "maxIndexedOrSolutionsReached" : false,
                "maxIndexedAndSolutionsReached" : false,
                "maxScansToExplodeReached" : false,
                "winningPlan" : {
                        "stage" : "FETCH",
                        "inputStage" : {
                                "stage" : "IXSCAN",
                                "keyPattern" : {
                                        "dob.age" : 1,
                                        "gender" : 1
                                },
                                "indexName" : "dob.age_1_gender_1",
                                "isMultiKey" : false,
                                "multiKeyPaths" : {
                                        "dob.age" : [ ],
                                        "gender" : [ ]
                                },
                                "isUnique" : false,
                                "isSparse" : false,
                                "isPartial" : false,
                                "indexVersion" : 2,
                                "direction" : "forward",
                                "indexBounds" : {
                                        "dob.age" : [
                                                "[35.0, 35.0]"
                                        ],
                                        "gender" : [
                                                "[MinKey, MaxKey]"
                                        ]
                                }
                        }
                },
                "rejectedPlans" : [ ]
        },
        "executionStats" : {
                "executionSuccess" : true,
                "nReturned" : 95,
                "executionTimeMillis" : 0,
                "totalKeysExamined" : 95,
                "totalDocsExamined" : 95,
                "executionStages" : {
                        "stage" : "FETCH",
                        "nReturned" : 95,
                        "executionTimeMillisEstimate" : 0,
                        "works" : 96,
                        "advanced" : 95,
                        "needTime" : 0,
                        "needYield" : 0,
                        "saveState" : 0,
                        "restoreState" : 0,
                        "isEOF" : 1,
                        "docsExamined" : 95,
                        "alreadyHasObj" : 0,
                        "inputStage" : {
                                "stage" : "IXSCAN",
                                "nReturned" : 95,
                                "executionTimeMillisEstimate" : 0,
                                "works" : 96,
                                "advanced" : 95,
                                "needTime" : 0,
                                "needYield" : 0,
                                "saveState" : 0,
                                "restoreState" : 0,
                                "isEOF" : 1,
                                "keyPattern" : {
                                        "dob.age" : 1,
                                        "gender" : 1
                                },
                                "indexName" : "dob.age_1_gender_1",
                                "isMultiKey" : false,
                                "multiKeyPaths" : {
                                        "dob.age" : [ ],
                                        "gender" : [ ]
                                },
                                "isUnique" : false,
                                "isSparse" : false,
                                "isPartial" : false,
                                "indexVersion" : 2,
                                "direction" : "forward",
                                "indexBounds" : {
                                        "dob.age" : [
                                                "[35.0, 35.0]"
                                        ],
                                        "gender" : [
                                                "[MinKey, MaxKey]"
                                        ]
                                },
                                "keysExamined" : 95,
                                "seeks" : 1,
                                "dupsTested" : 0,
                                "dupsDropped" : 0
                        }
                }
        },
        "command" : {
                "find" : "infos",
                "filter" : {
                        "dob.age" : 35
                },
                "$db" : "persons"
        }
}
```

But if we only search will the gender then index has no use because gender is not sorted primarily. It is secondary sort on the dob.age. Here mongodb will use the full COLLSCAN.
```js
> db.infos.explain("executionStats").find({"gender" : "male"})
{
        "explainVersion" : "1",
        "queryPlanner" : {
                "namespace" : "persons.infos",
                "indexFilterSet" : false,
                "parsedQuery" : {
                        "gender" : {
                                "$eq" : "male"
                        }
                },
                "maxIndexedOrSolutionsReached" : false,
                "maxIndexedAndSolutionsReached" : false,
                "maxScansToExplodeReached" : false,
                "winningPlan" : {
                        "stage" : "COLLSCAN",
                        "filter" : {
                                "gender" : {
                                        "$eq" : "male"
                                }
                        },
                        "direction" : "forward"
                },
                "rejectedPlans" : [ ]
        },
        "executionStats" : {
                "executionSuccess" : true,
                "nReturned" : 2435,
                "executionTimeMillis" : 4,
                "totalKeysExamined" : 0,
                "totalDocsExamined" : 5000,
                "executionStages" : {
                        "stage" : "COLLSCAN",
                        "filter" : {
                                "gender" : {
                                        "$eq" : "male"
                                }
                        },
                        "nReturned" : 2435,
                        "executionTimeMillisEstimate" : 0,
                        "works" : 5002,
                        "advanced" : 2435,
                        "needTime" : 2566,
                        "needYield" : 0,
                        "saveState" : 5,
                        "restoreState" : 5,
                        "isEOF" : 1,
                        "direction" : "forward",
                        "docsExamined" : 5000
                }
        },
        "command" : {
                "find" : "infos",
                "filter" : {
                        "gender" : "male"
                },
                "$db" : "persons"
        }
}
```

**Sorting with indexing:**

If we are sorting on any field and that field has an indexing, then mongodb will not sort it will directly use the indexed records as mongodb already has a sorted list on that field.

If we are trying to sort on a large number of documents, then it will time out. MongoDB has a memory of `32 megabytes` of memory of sorting. By default, mongodb loads all the documents on its memory then it sorts on them. So, without indexing sometimes it is not possible to get the sorted documents.

When we are creating any index on that time, we can specify that the index will be `unique` or not. By default, the indexing on `$id` holds unique criteria.
```js
> db.infos.createIndex({ email : 1 }, { unique : true })
```

Before creating index if there is already any duplicate email available then it will throw an error.
```js
> db.infos.createIndex({ email : 1 }, { unique : true })
{
        "ok" : 0,
        "errmsg" : "Index build failed: 8aff9b57-7fce-4ff9-8631-4f22c63ddaff: Collection persons.infos ( c6d8709f-2a51-4bda-ac9e-343a639304d6 ) :: caused by :: E11000 duplicate key error collection: persons.infos index: email_1 dup key: { email: \"abigail.clark@example.com\" }",
        "code" : 11000,
        "codeName" : "DuplicateKey",
        "keyPattern" : {
                "email" : 1
        },
        "keyValue" : {
                "email" : "abigail.clark@example.com"
        }
}
```




## Partial filter/Indexing

We can always use compound indexing but the problem with the compound indexing is that it takes much space in discs. So, in that case we can use partial filter like if we know that gender male is frequently queried rather than female. So, we can create a partial index with gender male.


Creating a partial index on gender `male`
```js
> db.infos.createIndex({"dob.age" : 1}, {partialFilterExpression : {"gender" : 1}} )
{
        "numIndexesBefore" : 1,
        "numIndexesAfter" : 2,
        "createdCollectionAutomatically" : false,
        "ok" : 1
}
```

Getting all the index information
```js
> db.infos.getIndexes()
[
    {
        "v" : 2,
        "key" : {
            "_id" : 1
        },
        "name" : "_id_"
    },
    {
        "v" : 2,
        "key" : {
            "dob.age" : 1
        },
        "name" : "dob.age_1",
        "partialFilterExpression" : {
            "gender" : 1
        }
    }
]
```

Drawback of this partial filter is that now when we just query for the `“dob.age”` it will not use `IXSCAN` it will use the `COLLSCAN`. But if we also mention gender male then it will use the `IXSCAN`.

Advantage of partial filter is that now the write query is more efficient as the size of the ordered list is small.

If we have an index on `email` and `unique true` and if we enter document `without email` then mongodb will treat that document as email equal to `null`. Again, if we try to `insert` any document `without` email then mongoDB will `throw an exception` as email `null` is already stored in ordered list. We cannot add null value again.

To allow this condition we can use unique true with partial filter expression.
```js
> db.infos.createIndex({"dob.age" : 1}, {unique : true, partialFilterExpression : {"email" : {exists : true}}} )
{
        "numIndexesBefore" : 1,
        "numIndexesAfter" : 2,
        "createdCollectionAutomatically" : false,
        "ok" : 1
}
```

## Time to live index(TTL)

It is only applicable for `date or timestamp`. With this indexing after certain time the document will automatically be `deleted`.

If there is already some document and then we are adding this `index`, then at the time of index creation **it will not check the existing documents**. When we insert any new data then it will evaluate all the documents again and then it will use `TTL` index.

```js
> db.sessions.createIndex({ createdAt : 1} , {expireAfterSeconds : 10})

> db.sessions.insertOne({data : "I am Abhishek", createdAt : new Date()})
{
    "acknowledged" : true,
    "insertedId" : ObjectId("62da72b385a6e4bfe5a374cb")
}

> db.sessions.findOne()
{
    "_id" : ObjectId("62da72b385a6e4bfe5a374cb"),
    "data" : "I am Abhishek",
    "createdAt" : ISODate("2022-07-22T09:49:39.459Z")
}

> db.sessions.createIndex({ createdAt : 1} , {expireAfterSeconds : 10})
{
    "numIndexesBefore" : 1,
    "numIndexesAfter" : 2,
    "createdCollectionAutomatically" : false,
    "ok" : 1
}
```

Now with this index the documents will be delete after `10` seconds.
This can be useful for session or carts in online shopping where the cart item automatically deletes after one day.



## Query Diagnosis and & Query Planning

**explain() method takes three type of string:**

- "queryPlanner": Show summary for executed query and winning plan
- "executionStats": Show detailed summary for executed query and winning plan and rejected plans.
- "allPlansExecution": Show detailed summary for executed query and winning plan and winning plan decision process.

**For determining the query is efficient or not we must check following things:**

Processing time in milliseconds, no of keys examined (if index scan happened), No of documents examined, no of documents returned.

The keys and documents examined should be close together and documents examined and returned should be closed or documents should be zero so that it looked at zero documents. 
In a so-called covered query, it will be happening.


**Covered query:**

If we have an indexing on name and we are only querying for name on that time mongodb will not even look to the documents, instead it will directly return the name from the indexed ordered list.

Example of this type of query is like:
```js
db.infos.findOne({ “name” : “Abhishek”}, { _id: 0, name : 1})
```


Suppose we have an index on `name` and another index one `age and name` (the ordering is important here). Now if we search for any document with `name and age` then mongodb will use the `compound index`, it will use the single index on `name`. If we do an `explain("executionStats")` then `age_1_name_1` will fall under `winning plan` and `name_1` will fall under rejected plans.

To find the `winning plan` mongodb check the query and available index then it will choose among them. So every time there is a query mongodb tries to find a `winning plan`, but again it will be having the extra step to find among all the plans. So mongodb save the winning plan in the caches for the query. This cache is not for forever. Mongodb resets the cache after db restarts, after few inserts or there is any rebuilt of index or changes in index.



## Multikey index

We can also create indexes on array values. Let’s say we are adding one document like this.
```js
> db.infos.insertOne({"name" : "Abhishek", "gender" : "male", "hobbies" : ["Sports", "Coding"]})
{
        "acknowledged" : true,
        "insertedId" : ObjectId("62dcaf7185a6e4bfe5a374cc")
}
> db.infos.createIndex({hobbies: 1})
{
        "numIndexesBefore" : 1,
        "numIndexesAfter" : 2,
        "createdCollectionAutomatically" : false,
        "ok" : 1
}
> db.infos.explain().find({hobbies : "Coding"})
{
    "explainVersion" : "1",
    "queryPlanner" : {
        "namespace" : "persons.infos",
        "indexFilterSet" : false,
        "parsedQuery" : {
            "hobbies" : {
                "$eq" : "Coding"
            }
        },
        "queryHash" : "895C9692",
        "planCacheKey" : "439794C9",
        "maxIndexedOrSolutionsReached" : false,
        "maxIndexedAndSolutionsReached" : false,
        "maxScansToExplodeReached" : false,
        "winningPlan" : {
            "stage" : "FETCH",
            "inputStage" : {
                "stage" : "IXSCAN",
                "keyPattern" : {
                    "hobbies" : 1
                },
                "indexName" : "hobbies_1",
                "isMultiKey" : true,
                "multiKeyPaths" : {
                    "hobbies" : [
                        "hobbies"
                    ]
                },
                "isUnique" : false,
                "isSparse" : false,
                "isPartial" : false,
                "indexVersion" : 2,
                "direction" : "forward",
                "indexBounds" : {
                    "hobbies" : [
                        "[\"Coding\", \"Coding\"]"
                    ]
                }
            }
        },
        "rejectedPlans" : [ ]
    },
    "command" : {
        "find" : "infos",
        "filter" : {
            "hobbies" : "Coding"
        },
        "$db" : "persons"
    },
}
```

Here `multikey` is true.

When we are creating index on array values. On that time there will be a ordered list with all the elements with array. It polls out all the elements of the array and stores as a separate element. So, it is larger than the size of the document.

If the array consists of documents, then we have to query with that document otherwise it will not use `IXSCAN`. Suppose we have address array with `homeAddress` and we are creating index on arrays.
```js
{ "address": [
    { "homeAddress" : "18 No alep khan mahalla road" }, 
    { "homeAddress" : "Rameswara waterview block 1,4B" }
]}
```

Here we have to search like this:
```js
db.infos.find({
    "address": { "homeAddress" : "18 No alep khan mahalla road" }
})
```
Otherwise indexing will not work. We can also use on `"address.homeAddress"`. <br>
We can create compound indexes with multikey index like with name and address array. <br>
It will do a `cartesian product` of the name and address values. Then it will store in the ordered list. <br>
But we cannot create a compound index if both values are array. <br>



## Text index

If we search using regex that is very low in performance rather, we can use text indexes.<br>
Text string is just an array of words. So, mongodb stores the main keywords and removes the stop words like "is", "the", "a" etc.<br>
The main thing with text index it we can only create on index, which is type of text, because it is expensive to store all the keywords. If we have any criteria to use on both rather, we can create compound index of type text with the two fields.
```js
db.infos.createIndex({ "description" : "text" })
```
We can not specify 1 or -1 while creating the index.

We can search like this. We cannot use regular queries. Text index is expensive, and we have to use it like this.
```js
db.infos.find({ "$text" : { "$search" : "pretty" }})
```




If we search for "red book" then the query `db.infos.find({ "$text" : { "$search" : "red book" }})` will not work as it will split the query string into multiple word, then it will search individually like it will search for red and it will search for book then it will combine the result. So, we have to use quotation mark around our query if we are searching for phrases.
```js
db.infos.find({ "$text" : { "$search" : "\"red book\"" }})
```


If we have more than one result, then behind the scenes mongodb assigns meta score to the documents. Higher the score means that the document matches with our query better. To see the score with have to project the score as well.
```js
db.infos.find(
    { $text : { $search : "awesome book" }}, 
    { score : { $meta : "textScore" }}
)
```

we can also show the results with sorted based on scores.
```js
db.infos.find(
    { $text : { $search : "awesome book" }} , 
    { score : { $meta : "textScore" }}
).sort({ 
    score : { $meta : "textScore" }
})
```

It will be a `decreasing` type of sorting. <br>
We can use more than field for text index. To drop an index of text, we must drop by name.
```js
db.infos.createIndex({ 
    title : "text" , 
    description : text 
})
```

it will create an index using the keywords of both fields. We can search like previous. Case does not matter for text index.
```js
db.infos.find({ 
    "$text" : { "$search" : "pretty" }
})
```

We can also rule out for the specific words.
```js
db.infos.find({ 
    "$text" : { "$search" : "pretty -books" }
})
```
we have to add minus `(-)` before that word. It will for `pretty word` where book word is not present.

We can also use language in text index as stop words for different language is different. Default language is English though. <br>
There is list of supported language that we can use. Default language is very important when it comes to text index. <br>

```js
db.infos.createIndex(
    { title : "text" }, 
    { default_laguage : "germany"}
)
```

We can also assign weight to the fields which will be used to create text index.
```js
db.infos.createIndex(
    { title : "text" , summary : "text" }, 
    { weights : { title : 5 , summary : 1 }
)
```

We also search in case sensitive way like the following.
```js
db.infos.find({ 
    "$text" : { "$search" : "pretty" }, 
    $caseSentitive : true 
})
```

## Building Index

When we are creating any index using createIndex method on that time the collection got locked. On that time if we try to insert any document then we have to wait for a certain time. The down time will depend on the size of the collection. It is adjustable in lower environment, but we cannot afford this in production. To deal with this create index in background. The time taken for creating the index is slow in background than foreground.
```js
db.infos.createIndex(
    { "age" : 1 } , 
    { "background" : true }
)
```
