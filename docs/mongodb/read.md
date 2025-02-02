
## Introduction

**Following are the components of mongodb reads**

- Methods, Filters and Operators
- Query Selectors
- Projection Operators


**There are two methods**

- `find`: returns all the documents which satisfies the criteria (basically it returns the cursor object)
- `findOne`: it returns a first document that satisfies the criteria

find method gives a cursor of 20 objects

Examples
```js
> db.products.findOne({age:24}) ->  to get the document where age is 24
> db.products.findOne({age:{$gt:24}}) -> to get the document where age is greater than 24
```


Operators are reserved fields started with dollar like $gt, $gte, $lt, $lte


**Query Selectors**

- Comparison
- Evaluation
- Logical
- Array
- Element
- Comments
- Geospatial


**Projection Operator**

- $
- $elemMatch
- $meta
- $slice


first it will search the document where name is "Under the Dome" then it only return name, type and language
```js
db.infos.find({"name": "Under the Dome"},{"name":1,"type":1,"language":1})
```

runtime equal to 60, both of them will work same
```js
db.infos.findOne({runtime:60})

db.infos.findOne({runtime:{$eq:60}})
```

runtime not equal to 60
```js
db.infos.findOne({runtime:{$ne:60}}) 
```

runtime greater than 60
```js
db.infos.findOne({runtime:{$gt:60}})
```

runtime greater than equal to 60
```js
db.infos.findOne({runtime:{$gte:60}})
```

runtime less than 60
```js
db.infos.findOne({runtime:{$lt:60}})
```

runtime less than equal to 60
```js
db.infos.findOne({runtime:{$lte:60}}) 
```

it will find all the documents where runtime is either 30 or 42
```js
db.infos.find({runtime: {$in: [30,42]}}) 
```

it will find all the documents where runtime is neither 30 nor 42
```js
db.infos.find({runtime: {$nin: [30,42]}}) 
```

average is a field which is inside of rating, so to querying anything in average we can use something like this layer1.layer2.layer3.targetField then our query operator
```js
db.infos.findOne({"rating.average": {$gt: 9}}) 
```

here genres is a array. If we search for this, it will not equate as a string it will check that genres contain Drama or not
```js
db.infos.findOne({"genres": "Drama"}) 
```

`$or` operator takes an array of queries. Here average is either greater than 8 or less than 7. We can combine more than two queries.
```js
db.infos.find({$or: [{"rating.average": {$gt: 8}}, {"rating.average": {$lt: 7}}]}) 
```

`$nor` operator takes an array of queries. Here average is neither greater than 8 nor less than 7. We can combine more than two queries.
```js
db.infos.find({$nor : [{"rating.average": {$gt: 8}}, {"rating.average": {$lt: 7}}]}) 
```

`$and` operator takes an array of queries. Here average is less than 8 and greater than 7. We can combine more than two queries. We have a short cut for and query.
```js
db.infos.find({$and : [{"rating.average": {$lt:8}},{"rating.average": {$gt:7}}]}) 
```

these two queries are same as mongodb by default does the and operation and equal to operation
```js
db.infos.find({$and : [{"rating.average": {$lt:8}},{"runtime": {$gte:60}}]})

db.infos.find({"rating.average": {$lt:8}, "runtime": {$gte:60}})
```

we have also `$not` operator that we can use like this. `$not` is just like another wrapper to the existing query

not of this query `db.infos.find({"rating.average": {$lt: 8}}).count()` will be `db.infos.find({"rating.average": {$not :{$lt: 8}}}).count()`

There are two element type operators `$exist` and `$type`

As mongodb is schemaless so sometimes there may be a case a **field** may or may not be **exist** so we can check that a field is exist or not like this:

age field exists
```js
db.users.findOne({"age": {$exists: true}})
```

We can use exists with another query as well

age field exists and greater than 30
```js
db.users.findOne({"age": {$exists: true, $gte: 30}})
```

age field exists and not equal to null
```js
db.users.findOne({"age": {$exists: true, $ne: null}}) 
```

As mongodb is schemaless so sometimes there may be a case a field may or may not have the same data type for all the document so we can check that a field has the datatype or not with `$type`

phone no is double in which document
```js
db.users.findOne({"phoneNo": {$type: "double"}}) 
```

phone no is string in which document
```js
db.users.findOne({"phoneNo": {$type: "string"}}) 
```

phone no is string or double in which document. We can use array. It will act as OR operator here
```js
db.users.findOne({"phoneNo": {$type: ["double", "string"]}})
```

It will use regex to search any document have the musical word in the summary or not. But it is not that efficient better to use text indexing
```js
db.infos.find({summary: {$regex: /musical/}}) 
```

it will search all the documents where weight is greater that runtime. We can use $expr like this where it will take the query inside it. 
```js
db.infos.find({$expr: {$gt: ["$weight", "$runtime"]}}) 
```


We can use if, then an inside $cond and the $expr will evaluate everything.


## Querying to Arrays