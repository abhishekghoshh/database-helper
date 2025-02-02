
## Primitive types

- Text -> `"Abhishek Ghosh"`
- Boolean -> `true`
- Number -> 
    - `NimberInt()` -> 1
    - `Integer(int32)` -> 55
    - `NumberLong(int64)` -> 1000000000
    - `NumberDecimal` -> 12.0009
- ObjectId -> `ObjectId("62a6fddadb132197c5e8879f")`
- ISODate -> `2022-06-14T05:45:29.379+00:00`
- Timestamp 
- Embedded Documents
- Arrays

`Db.stats()` will bring the statistic of the database.


MongoDB has a couple of hard limits - most importantly, a single document in a collection (including all embedded documents it might have) must be less than equal to `16mb`. Additionally, you may only have `100 levels of embedded documents`.

You can find all limits (in great detail) here: [MongoDB Limits and Thresholds](https://docs.mongodb.com/manual/reference/limits/)

For the data types, MongoDB supports, you find a detailed overview on this page: [BSON Types](https://docs.mongodb.com/manual/reference/bson-types/)


**Important data type limits are:**

- Normal integers (int32) can hold a maximum value of `-2,147,483,647 to +2,147,483,647`
- Long integers (int64) can hold a maximum value of `-9,223,372,036,854,775,807 to +9,223,372,036,854,775,807`
- Text can be as long as you want - the limit is the `16mb` restriction for the overall document

It's also important to understand the difference between `int32 (NumberInt)`, `int64 (NumberLong)` and a normal number as you can enter it in the shell.

The same goes for a `normal double` and `NumberDecimal`.

`NumberInt` creates a `int32` value => `NumberInt(55)` and `NumberLong` creates a `int64` value => `NumberLong(7489729384792)`

If you just use a number e.g. `insertOne({age: 1})`, this will get added as a `normal double` into the database. 

The reason for this is that the shell is based on `JS` which only knows `float/double` values and doesn't differ between `integers` and `floats`.

`NumberDecimal` creates a high-precision double value e.g. `NumberDecimal("12.99")`
This can be helpful for cases where you need (many) exact decimal places for calculations.

When not working with the shell but a MongoDB driver for your app programming language (e.g. PHP, .NET, Node.js, ...), you can use the driver to create these specific numbers.

Example for [Node.js](http://mongodb.github.io/node-mongodb-native/3.1/api/Long.html)


This will allow you to build a `NumberLong` value like this
```js
const Long = require('mongodb').Long;
db.collection('wealth')
    .insert({ value: Long.fromString("121949898291")});
```

## Embedded documents vs reference id

### Embedding is better for
- Small subdocuments
- Data that does not change regularly
- When eventual consistency is acceptable
- Documents that grow by a small amount
- Data that you'll often need to perform a second query to fetch Fast reads

### References are better for
- Large subdocuments
- Volatile data
- When immediate consistency is necessary
- Documents that grow a large amount
- Data that youll often exclude from the results
- Fast writes


Refference : [Data Modeling](https://www.mongodb.com/docs/manual/core/data-model-design/)

We can also use aggregation framework for joining.

The MongoDB `lookup` operator, by definition, `Performs a left outer join to an unshared collection in the same database to filter in documents from the "joined" collection for processing.`
Simply put, using the MongoDB `lookup` operator makes it possible to merge data from the document you are running a query on and the document you want the data from.


**More can be found in the following links**

- [MongoDB Lookup Aggregations: Syntax, Usage & Practical Examples 101](https://hevodata.com/learn/mongodb-lookup/)
- [$lookup (aggregation)](https://www.mongodb.com/docs/manual/reference/operator/aggregation/lookup/)


## Data validation

Though Mongodb is schema less but we real life scenario we must have certain type of structure. We can add validators when we are creating any collection.
```js
db.createCollection('posts', {
    validator: {
      $jsonSchema: {
        bsonType: 'object',
        required: ['title', 'text', 'creator', 'comments'],
        properties: {
          title: {
            bsonType: 'string',
            description: 'must be a string and is required'
          },
          text: {
            bsonType: 'string',
            description: 'must be a string and is required'
          },
          creator: {
            bsonType: 'objectId',
            description: 'must be an objectid and is required'
          },
          comments: {
            bsonType: 'array',
            description: 'must be an array and is required',
            items: {
              bsonType: 'object',
              required: ['text', 'author'],
              properties: {
                text: {
                  bsonType: 'string',
                  description: 'must be a string and is required'
                },
                author: {
                  bsonType: 'objectId',
                  description: 'must be an objectid and is required'
                }
              }
            }
          }
        }
      }
    }
  });
```



If the collection is already created, then we can use run command to add validations and also, we can add validation level
```js
db.runCommand({
    collMod: 'posts',
    validator: {
      $jsonSchema: {
        bsonType: 'object',
        required: ['title', 'text', 'creator', 'comments'],
        properties: {
          title: {
            bsonType: 'string',
            description: 'must be a string and is required'
          },
          text: {
            bsonType: 'string',
            description: 'must be a string and is required'
          },
          creator: {
            bsonType: 'objectId',
            description: 'must be an objectid and is required'
          },
          comments: {
            bsonType: 'array',
            description: 'must be an array and is required',
            items: {
              bsonType: 'object',
              required: ['text', 'author'],
              properties: {
                text: {
                  bsonType: 'string',
                  description: 'must be a string and is required'
                },
                author: {
                  bsonType: 'objectId',
                  description: 'must be an objectid and is required'
                }
              }
            }
          }
        }
      }
    },
    validationAction: 'warn'
  });
```

**Helpful Articles/ Docs:**

- [MongoDB Limits and Thresholds](https://docs.mongodb.com/manual/reference/limits/)
- [BSON Types](https://docs.mongodb.com/manual/reference/bson-types/)
- [Schema Validation](https://docs.mongodb.com/manual/core/schema-validation/)

We can configure mongodb server in with various arguments. We can check all in mongod --help command.

We can also use mongod.cfg to put all our configurations in a file and we can put it inside any folder and to we have use that file when we are about to start the server.

mongod -f /path/mongod.cfg
```
storage:
  dbPath: "/your/path/to/the/db/folder"
systemLog:
  destination: file
  path: "/your/path/to/the/logs.log"
```
Reference: [Self-Managed Configuration File Options](https://www.mongodb.com/docs/manual/reference/configuration-options/)

**Helpful Articles/ Docs:**

- More Details about Config Files: [Self-Managed Configuration File Options](https://docs.mongodb.com/manual/reference/configuration-options/)
- More Details about the Server (mongod) Options: [mongod](https://docs.mongodb.com/manual/reference/program/mongod/)
