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

The documents in the collection would be at the "addresses" a1, a2 and a3. The order does not have to match the order in the index

