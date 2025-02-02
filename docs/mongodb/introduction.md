

## What is Mongodb ? 
MongoDB is a document-oriented NoSQL database which is used to store huge data as documents.
It has collection just like tables in relational databases.
It has no schema. We can use JSON object to store data here but behind the scenes mongodb server stores this json into binary format.


## What is mongod?
It is a ececutable file, used to start the mongodb server locally


## What is mongo/mongosh?
It is a mongodb shell, used to connect to mongodb to execute our queries.

We can specify the location where we want to save our data in local. But it should have data and logs folder inside it. 
Then start the server like the following:
```
mongod --dbpath /path/data --logpath /path/logs/mongo.log
```

### How do I start/stop MongoDB from running in the background in windows?

In Windows there is an option to start mongodb as a service so it will be running all the time in background.
One liner to start or stop mongodb service using command line in windows. </br>

- To start the service use: `NET START MONGODB` </br>

- To stop the service use: `NET STOP MONGODB` </br>


### How do I start/stop MongoDB from running in the background in MAC/linux?

--fork option is used to run mongoDB in background.
```
mongod --port 8888 --dbpath /Users/Shared/data/db --logpath /Users/Shared/log/mongo.log --fork
```
We can shut down the mongodb by first switching to `admin db` then use this command `db.shutdownServer()`

Command to show all the database: `show dbs `

Create or use a database: `use <db_name>`

To use a collection and store one data: `db.products.insertOne({name:"Abhishek Ghosh",age:24})`

it will create a document in products collection. After inserting one document it will give one `id` and acknowledgement. We can also insert nested documents.

To show all the datas in products collection use this command: `db.products.find()`

To show it in a json structure: `db.products.find().pretty()`

By default, mongodb adds an unique id which is of type `ObjectId` to every document and we can search items with that 
and also mongodb create one default index with this _id by default. We can also add our `_id` like the following 
```
db.products.insertOne({_id:"abhishek-test-0001",name:"Abhishek Ghosh"})
```
To search any document using `_id` : `db.products.find({_id:ObjectId('62a6ff6edb132197c5e887a0')})`

Mongodb uses `BSON` instead of `JSON` to store data. 

Maximum size of document can be `16 mb`

## Tutorials

### Website
- [neetcode](https://neetcode.io/courses/lessons/mongodb)
- [MongoDB Developer](https://www.mongodb.com/developer/products/mongodb/cheat-sheet/)

### Youtube
- [MongoDB Crash Course](https://www.youtube.com/watch?v=QPFlGswpyJY)

### Udemy
- [MongoDB - The Complete Developer's Guide](https://www.udemy.com/course/mongodb-the-complete-developers-guide/)
- [MongoDB : A Complete Database Administration Course](https://www.udemy.com/course/mongodb-a-complete-course-on-database-administration/)