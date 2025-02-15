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

Let's say experience is an array having many fields like college name, company name, start date end date etc

it will search the document where in experiences array there will be a object in which companyName field will be Kreeti
```js
db.products.find({"experiences.companyName": "Kreeti"}) 
```

We can use dot operator with array and embedded documents

find all the documents where experience is length of 3
```js
db.products.find({"experiences": {$size: 3}}) 
```

`$size` operator takes only equality it will not work with `$gt` or `$lt` like the following query

It will give us the exception.
```js
db.products.find({"experiences": {$size: {$gt: 2}}}) 
```

It will only search for the documents where genres is `["Drama", "Crime", "Thriller"]` particularly in this order but if the order does not matter for us then we can use `$all`
```js
db.infos.find({genres: ["Drama", "Crime", "Thriller"]}) 
```

It will search for all the documents where these three items `["Drama", "Crime", "Thriller"]` are there in the genres array.
```js
db.infos.find({genres: {$all: ["Drama", "Crime", "Thriller"]}}) 
```

Certainly, these two queries will not give us the same result:
```js
db.infos.find({genres: {$all: ["Drama", "Crime"]}}).count() -> 47

db.infos.find({genres: ["Drama", "Crime"]}).count() -> 12
```

Find how many persons are working in TCS or not. Probable answers are :
```js
db.products.find({"experiences.companyName": "TCS","experiences.currentlyInHere": true}).count()

db.products.find({$and: [{"experiences.companyName": "TCS"}, {"experiences.currentlyInHere": true}]}).count()
```

If we use this query ideally it should return `1` as there is only one document where in one `experience` item `companyName` is `TCS` and `currentlyHere` is `true` but this query does not work like that it will check in the `arrays` that if any object has the `companyName` as `TCS` and `currentlyHere` is `true`. It does not need to be the same object in the array. Here we could use the `$elemMatch`. It will search for all the queries in the same item of the array.

We can achieve our requirement of any person who is currently working in TCS or not with the below query:
`$elemMatch` will match all the queries for every element in the array.
```js
db.products.find({experiences: {$elemMatch: {companyName: "TCS",currentlyInHere: true}}}).count()
```

## Cursor

In `MongoDB`, the `find()` method return the `cursor`, now to access the document we need to iterate the `cursor`. In the `mongo shell`, if the `cursor` is not assigned to a `var` keyword then the `mongo shell` automatically iterates the `cursor` up to `20` documents. `MongoDB` also allows you to iterate cursor manually. So, to iterate a cursor manually simply assign the cursor return by the `find()` method to the `var` keyword or JavaScript variable.

**Note**: If a `cursor` inactive for `10 min`, then `MongoDB` server will automatically close that cursor.

It will fetch the `cursor` of first 20 elements.
```js
db.infos.find().pretty() 
```

It will exhaust the `cursor` and make all the documents as `array` of objects
```js
db.infos.find().toArray()
```

It give us the `count` of all the element
```js
db.infos.find().count() 
```

it will say if the `cursor` has exhausted or not
```js
db.infos.find().hasNext()
```

it will give the current `20` elements of the `cursor`
```js
db.infos.find().next() 
```

`printjson` is a method in `shell`. `forEach` is a function on the `cursor`
```js
db.infos.find().forEach((doc) => printjson(doc)) 
```

It will `sort` all the elements on `average` element on rating.
```js
db.infos.find().sort({"rating.average" :1}) 
```

It will `sort` all the elements on `average` element on rating and then runtime but backwards
```js
db.infos.find().sort({"rating.average" :1, "runtime": -1})
```

It will sort all the elements on `average` element on rating then skip the first 10 elements
```js
db.infos.find().sort({"rating.average" :1}).skip(10)  
```

It will sort all the elements on `average` element on rating then only show the first `2` elements
```js
db.infos.find().sort({"rating.average" :1}).limit(2) 
```

It will sort all the elements on `average` element on rating then `skip 2 elements` and show only `2` elements
```js
db.infos.find().sort({"rating.average" :1}).skip(2).limit(2) 
```

It will show only the `name` and the `_id` of first `20` documents. `_id` is shown by default.
```js
db.infos.find({},{name: 1}) 
```

It will show only the name of first `20` documents.
```js
db.infos.find({},{_id: 0, name: 1}) 
```

It will show only the `name` and `schedule` object with only `time` field and the `_id` of first `20` documents.
```js
db.infos.find({},{name: 1, "schedule.time": 1}) 
```

It will first search for the documents with `genres` with `Thriller` then with `projection` it will show only the `first` element of genres array
```js
db.infos.find({genres: "Thriller"},{"genres.$": 1}) 
```

It will first search for the documents with genres array with `Drama and Action` then with projection it will show only the `first` element of genres array
```js
db.infos.find({genres: {$all : ["Drama","Action"]}},{"genres.$": 1}) 
```

Here Querying and projecting works independently. First it will search for genres array with `Drama and Action` then with `projection` it will show only the array with `Horror` present or not.
```js
db.infos.find({genres: {$all : ["Drama","Action"]}},{"genres" : {$elemMatch: {$eq: "Horror"}}}) 
```

`$slice` only works array while projection. `{$slice: 2}` will slice the first `2` elements of the array.
```js
db.infos.find({}, {genres: {$slice: 2}, name: 1}) 
```

`{$slice: [1,3]}` will slice the `1st` to `3rd` elements of the array.
```js
db.infos.find({},{genres: {$slice: [1,3]},name: 1}) 
```



## More Examples 

**Find one document:**
```js
db.coll.findOne()
```

**Find all documents (returns a cursor - show 20 results - "it" to display more):**
```js
db.coll.find()
```

**Find all documents and pretty print:**
```js
db.coll.find().pretty()
```

**Find documents with specific criteria (implicit logical "AND"):**
```js
db.coll.find({name: "Max", age: 32})
```

**Find documents with a specific date:**
```js
db.coll.find({date: ISODate("2020-09-25T13:57:17.180Z")})
```

**Find documents with specific criteria and explain execution stats:**
```js
db.coll.find({name: "Max", age: 32}).explain("executionStats")
```

**Find distinct values for a field:**
```js
db.coll.distinct("name")
```

**Count documents with specific criteria (accurate count):**
```js
db.coll.countDocuments({age: 32})
```

**Estimate document count based on collection metadata:**
```js
db.coll.estimatedDocumentCount()
```

**Find documents with comparison operators:**
```js
db.coll.find({"year": {$gt: 1970}})
db.coll.find({"year": {$gte: 1970}})
db.coll.find({"year": {$lt: 1970}})
db.coll.find({"year": {$lte: 1970}})
db.coll.find({"year": {$ne: 1970}})
db.coll.find({"year": {$in: [1958, 1959]}})
db.coll.find({"year": {$nin: [1958, 1959]}})
```

**Find documents with logical operators:**
```js
db.coll.find({name: {$not: {$eq: "Max"}}})
db.coll.find({$or: [{"year": 1958}, {"year": 1959}]})
db.coll.find({$nor: [{price: 1.99}, {sale: true}]})
db.coll.find({
  $and: [
    {$or: [{qty: {$lt :10}}, {qty :{$gt: 50}}]},
    {$or: [{sale: true}, {price: {$lt: 5 }}]}
  ]
})
```

**Find documents with element operators:**
```js
db.coll.find({name: {$exists: true}})
db.coll.find({"zipCode": {$type: 2 }})
db.coll.find({"zipCode": {$type: "string"}})
```

**Aggregation Pipeline:**
```js
db.coll.aggregate([
  {$match: {status: "A"}},
  {$group: {_id: "$cust_id", total: {$sum: "$amount"}}},
  {$sort: {total: -1}}
])
```

**Text search with a "text" index:**
```js
db.coll.find({$text: {$search: "cake"}}, {score: {$meta: "textScore"}}).sort({score: {$meta: "textScore"}})
```

**Find documents with regex:**
```js
db.coll.find({name: /^Max/})   // regex: starts by letter "M"
db.coll.find({name: /^Max$/i}) // regex case insensitive
```

**Find documents with array operators:**
```js
db.coll.find({tags: {$all: ["Realm", "Charts"]}})
db.coll.find({field: {$size: 2}}) // impossible to index - prefer storing the size of the array & update it
db.coll.find({results: {$elemMatch: {product: "xyz", score: {$gte: 8}}}})
```

**Projections:**
```js
db.coll.find({"x": 1}, {"actors": 1})               // actors + _id
db.coll.find({"x": 1}, {"actors": 1, "_id": 0})     // actors
db.coll.find({"x": 1}, {"actors": 0, "summary": 0}) // all but "actors" and "summary"
```

**Sort, skip, limit:**
```js
db.coll.find({}).sort({"year": 1, "rating": -1}).skip(10).limit(3)
```

**Read Concern:**
```js
db.coll.find().readConcern("majority")
```

Since shell is made of JS so we can use JS function
For reference: [Cursor Methods](https://www.mongodb.com/docs/manual/reference/method/js-cursor/)