## What is MongoDB?
MongoDB is a document-oriented NoSQL database used to store large amounts of data as documents. It has collections similar to tables in relational databases. It has no schema. We can use JSON objects to store data, but behind the scenes, the MongoDB server stores this JSON in binary format.

### What is `mongod`?
It is an executable file used to start the MongoDB server locally.

### What is `mongosh`?
It is a MongoDB shell used to connect to MongoDB to execute queries.

We can specify the location where we want to save our data locally. It should have `data` and `logs` folders inside it. Then start the server like the following:
```
mongod --dbpath /path/data --logpath /path/logs/mongo.log
```

### Connect to MongoDB Shell
```sh
mongosh // connects to mongodb://127.0.0.1:27017 by default
mongosh "mongodb+srv://cluster-name.abcde.mongodb.net/<dbname>" --username <username> // MongoDB Atlas
mongosh --host <host> --port <port> --authenticationDatabase admin -u <user> -p <pwd> # omit the password if you want a prompt
mongosh "mongodb://<user>:<password>@192.168.1.1:27017"
mongosh "mongodb://192.168.1.1:27017"
mongosh "mongodb+srv://cluster-name.abcde.mongodb.net/<dbname>" --apiVersion 1 --username <username> # MongoDB Atlas
```

## Install MongoDB

[Install MongoDB Community Edition](https://www.mongodb.com/docs/manual/installation/)

### Windows 

How do I start/stop MongoDB from running in the background in Windows?

In Windows, there is an option to start MongoDB as a service so it will be running all the time in the background. One-liner to start or stop MongoDB service using the command line in Windows:

- To start the service use: `NET START MONGODB`
- To stop the service use: `NET STOP MONGODB`

###  MacOS/Linux

How do I start/stop MongoDB from running in the background in macOS/Linux?

The `--fork` option is used to run MongoDB in the background.
```sh
mongod --port 8888 --dbpath /Users/Shared/data/db --logpath /Users/Shared/log/mongo.log --fork
```
We can shut down MongoDB by first switching to the `admin` database, then use this command:
```js
db.shutdownServer()
```

### Docker

How do I start/stop mongodb from docker
```sh
docker run \
  --rm \
  --name mongodb \
  -v ~/mongodb-data:/data/db \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=password \
  -p 27017:27017 \
  mongo
```

### Prod deployments

We can create production level [Replica Set](https://www.mongodb.com/developer/products/mongodb/cheat-sheet/#replica-set) and [Sharded Cluster](https://www.mongodb.com/developer/products/mongodb/cheat-sheet/#sharded-cluster)


## Common Commands

### Setup

MongoDB uses `BSON` instead of `JSON` to store data. The maximum size of a document can be `16 MB`.

**Show all databases:**
```sh
show dbs
```

**Create or use a database:**
```sh
use <db_name>
```

**Remove the database:**
```js
db.dropDatabase()
```

**Show all collections:**
```sh
show collections
```

**Create collections:**
```sh
db.createCollection("coll") // creates the collection `coll`
```

**Drop collections:**
```sh
db.coll.drop()    // removes the collection `coll`
```

**Create a collection with a `$jsonschema` validator:**
```js
// Create collection with a $jsonschema
db.createCollection("hosts", {
    validator: {$jsonSchema: {
        bsonType: "object",
        required: ["email"], // required fields
        properties: {
            // All possible fields
            phone: {
                bsonType: "string",
                description: "must be a string and is required"
            },
            email: {
                bsonType: "string",
                pattern: "@mongodb\.com$",
                description: "must be a string and match the regular expression pattern"
            },
        }
    }}
})

db.createCollection("contacts", {
   validator: {$jsonSchema: {
      bsonType: "object",
      required: ["phone"],
      properties: {
         phone: {
            bsonType: "string",
            description: "must be a string and is required"
         },
         email: {
            bsonType: "string",
            pattern: "@mongodb\.com$",
            description: "must be a string and match the regular expression pattern"
         },
         status: {
            enum: [ "Unknown", "Incomplete" ],
            description: "can only be one of the enum values"
         }
      }
   }}
})
```

**Run JavaScript File:**
```js
load("script.js")
```

**Get collection statistics:**
```js
db.coll.stats()
```

**Get collection storage size:**
```js
db.coll.storageSize()
```

**Get total index size of a collection:**
```js
db.coll.totalIndexSize()
```

**Get total size of a collection:**
```js
db.coll.totalSize()
```

**Validate a collection:**
```js
db.coll.validate({full: true})
```

**Rename a collection:**
```js
db.coll.renameCollection("new_coll", true) // 2nd parameter to drop the target collection if exists
```

### Insert

**Insert one document into a collection:**
```js
db.products.insertOne({
    name: "Abhishek Ghosh", 
    age: 24
})
```
This will create a document in the `products` collection. After inserting one document, it will give an `id` and acknowledgment. We can also insert nested documents.

**Insert many documents into a collection:**
```js
db.coll.insertMany([
    {name: "Navi", age: 25}, 
    {name: "Alice", age: 30}
])
```

By default, MongoDB adds a unique `ObjectId` to every document, and we can search items with that. MongoDB also creates a default index with this `_id` by default. We can also add our `_id` like the following:
```js
db.products.insertOne({_id: "abhishek-test-0001", name: "Abhishek Ghosh"})
```

### Find

**Show all documents in a collection:**
```js
db.products.find()
```

**List all documents with name "Navi" and age 25, and return only one document:**
```js
db.coll.find({
    name: "Navi", 
    age: 25
}).limit(1)
```

**Show documents in a JSON structure:**
```js
db.products.find().pretty()
```

**Search any document using `_id`:**
```js
db.products.find({_id: ObjectId('62a6ff6edb132197c5e887a0')})
```

**Count all documents in 'coll' collection:**
```js
db.coll.count()
```

**Count all documents with name "Navi":**
```js
db.coll.count({name: "Navi"})
```

**Find document and show execution stats:**
```js
db.coll.find({name: "Navi"}).explain("executionStats")
```

### Update

**Update all documents with name "Navi" and set age to 26:**
```js
db.coll.update({name: "Navi"}, {$set: {age: 26}})
```

**Update all documents with name "Navi" and increment age by 1:**
```js
db.coll.update({name: "Navi"}, {$inc: {age: 1}})
```

**Update all documents with name "Navi" and set age to null:**
```js
db.coll.update({name: "Navi"}, {$unset: {age: 1}})
```

**Remove age field from all documents with age field:**
```js
db.coll.updateMany({age: {$exists: true}}, {$unset: {age: ""}})
```

### Delete

**Remove all documents with name "Navi":**
```js
db.coll.deleteMany({name: "Navi"})
```

**Remove one document with name "Navi":**
```js
db.coll.deleteOne({name: "Navi"})
```

### Indexes

**List indexes:**
```js
db.coll.getIndexes()
```

**List index keys:**
```js
db.coll.getIndexKeys()
```

**Create index:**
```js
db.coll.createIndex({"name": 1})
```

**Create a compound index:**
```js
db.coll.createIndex({"name": 1, "date": 1})
```

**Drop index:**
```js
db.coll.dropIndex("name_1")
```

## ACID Compliance in MongoDB

| ACID Property | MongoDB Implementation |
|---------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Atomicity     | MongoDB ensures atomicity at the single-document level, meaning changes to a single document are always atomic. Starting with version 4.0, MongoDB provides multi-document transactions and guarantees the atomicity of the transactions. |
| Consistency    | MongoDB uses schema validation, a feature that allows you to define the specific structure of documents in each MongoDB collection. If the document structure deviates from the defined schema, MongoDB will return an error. This is how MongoDB enforces its version of consistency, however, it's optional and less rigid than in traditional SQL databases. |
| Isolation      | MongoDB isolates write operations on a per-document level. By default, clients do not wait for acknowledgement of write operations. However, users can configure write concern to guarantee a desired level of isolation. Multi-document transactions in MongoDB are isolated across participating nodes for the duration of each transaction. |
| Durability     | MongoDB allows you to specify the level of durability when writing documents. You can choose to wait until the data is written to a certain number of servers, or even to the disk. This is configurable by setting the write concern when writing data. |

## Tutorials

### Website
- [neetcode](https://neetcode.io/courses/lessons/mongodb)
- [MongoDB Developer](https://www.mongodb.com/developer/products/mongodb/cheat-sheet/)

### YouTube
- [MongoDB Crash Course](https://www.youtube.com/watch?v=QPFlGswpyJY)

### Udemy
- [MongoDB - The Complete Developer's Guide](https://www.udemy.com/course/mongodb-the-complete-developers-guide/)
- [MongoDB: A Complete Database Administration Course](https://www.udemy.com/course/mongodb-a-complete-course-on-database-administration/)