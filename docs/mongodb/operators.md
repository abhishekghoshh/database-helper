# Complex Operators

## Query and Projection Operators

**$eq**: Matches values that are equal to a specified value.
```js
{ field: { $eq: value } }
```

**$gt**: Matches values that are greater than a specified value.
```js
{ field: { $gt: value } }
```

**$gte**: Matches values that are greater than or equal to a specified value.
```js
{ field: { $gte: value } }
```

**$lt**: Matches values that are less than a specified value.
```js
{ field: { $lt: value } }
```

**$lte**: Matches values that are less than or equal to a specified value.
```js
{ field: { $lte: value } }
```

**$ne**: Matches all values that are not equal to a specified value.
```js
{ field: { $ne: value } }
```

**$in**: Matches any value in the specified array.
```js
{ field: { $in: [value1, value2, ...] } }
```

**$nin**: Matches none of the values specified in an array.
```js
{ field: { $nin: [value1, value2, ...] } }
```

## Logical Operators

**$or**: Joins query clauses with a logical OR, returns all documents that match the conditions of either clause.
```js
{ $or: [ { clause1 }, { clause2 } ] }
```

**$and**: Joins query clauses with a logical AND, returns all documents that match the conditions of both clauses.
```js
{ $and: [ { clause1 }, { clause2 } ] }
```

**$not**: Inverts the effect of a query expression and returns documents that do not match the query expression.
```js
{ field: { $not: { clause } } }
```

**$nor**: Joins query clauses with a logical NOR, returns all documents that fail to match both clauses.
```js
{ $nor: [ { clause1 }, { clause2 } ] }
```

## Array Operators

**$all**: Matches arrays that contain all elements specified in the query.
```js
{ field: { $all: [value1, value2, ...] } }
```

**$elemMatch**: Selects documents if element in the array field matches all the specified $elemMatch conditions.
```js
{ field: { $elemMatch: { clause1, clause2, ... } } }
```

**$size**: Selects documents if the array field is a specified size.
```js
{ field: { $size: size } }
```

## Update Operators

**$set**: Sets the value of a field in a document.
```js
{ $set: { field: value } }
```

**$unset**: Removes the specified field from a document.
```js
{ $unset: { field: "" } }
```

**$inc**: Increments the value of the field by the specified amount.
```js
{ $inc: { field: amount } }
```

**$mul**: Multiplies the value of the field by the specified amount.
```js
{ $mul: { field: amount } }
```

**$push**: Appends a specified value to an array.
```js
{ $push: { field: value } }
```

**$pop**: Removes the first or last element of an array.
```js
{ $pop: { field: 1 } } // Removes the last element
{ $pop: { field: -1 } } // Removes the first element
```

**$pull**: Removes all array elements that match a specified query.
```js
{ $pull: { field: { clause } } }
```

## Aggregation Operators

**$match**: Filters the documents to pass only documents that match the specified condition(s) to the next pipeline stage.
```js
{ $match: { clause } }
```

**$group**: Groups input documents by a specified identifier expression and applies the accumulator expression(s), if specified, to each group.
```js
{ $group: { _id: "$field", total: { $sum: "$amount" } } }
```

**$project**: Passes along the documents with only the specified fields to the next stage in the pipeline.
```js
{ $project: { field1: 1, field2: 1, _id: 0 } }
```

**$sort**: Sorts all input documents and outputs them to the next stage in the specified sort order.
```js
{ $sort: { field: 1 } } // Ascending order
{ $sort: { field: -1 } } // Descending order
```

**$limit**: Passes the first n documents unmodified to the pipeline where n is the specified limit.
```js
{ $limit: n }
```