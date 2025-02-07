
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
