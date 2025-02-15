## Introduction

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