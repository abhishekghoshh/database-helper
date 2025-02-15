## Create 
- `insertOne(data, options)` -> for inserting one item
- `insertMany(data, options)` -> for inserting multiple items

## Read 
- `find(filter, options)` -> find all the data based on the filter
- `findOne(filter, options)` -> find the first matching element based on the filter

## Update 
- `updateOne(filter, data, options)` -> to update one document
- `updateMany(filter, data, options)` -> for updating multiple documents
- `replaceOne(filter, data, options)` -> for replacing the entire document

## Delete 
- `deleteOne(filter, options)` -> delete only the first item with matching filter
- `deleteMany(filter, options)` -> delete all items matching with the filter

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

- When we find anything in the shell, rather than giving everything in one shot, it gives us the cursor of 20 elements, and to move to the next 20, we have to enter "it". To see it, we can use the `toArray` method on the cursor, which will exhaust the cursor and make one array with all the elements and show that.
- Cursor will fetch only the needed element.
- `findOne` will not give us a cursor object as it will only give us one element.
- `db.products.find().toArray()`
- `db.products.find().forEach((doc) => {printjson(doc)})

## What is projection?

- Rather than showing all the fields of a document, we can choose whatever we want to show.
- It will also help us to reduce the bandwidth usage as the server will not send all the elements.
- To get all the student's `name` with `age` equals `24`: 
```js
db.products.find({age: 24}, {name: 1})
```
- By default, `_id` is set to 1, so if we want to remove it as well, we have to use this type of query:
```js
db.products.find({age: 24}, {name: 1, _id: 0})
```
- One Document can hold a maximum of 100 levels of nesting.
