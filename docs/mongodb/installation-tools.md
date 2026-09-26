# MongoDB Installation and Tools

## MongoDB Server

The MongoDB Server (`mongod`) is the core database process responsible for handling data requests, managing data storage on disk, and background management operations like replication. It can be installed locally via package managers (`apt`, `brew`), run as a Docker container, or provisioned through a cloud provider. Configuration is controlled via a YAML config file or command-line flags, covering things like the data directory, bind IP, and port.

```bash
# macOS install via Homebrew
brew tap mongodb/brew
brew install mongodb-community@7.0
brew services start mongodb-community@7.0
```

**Interview Questions:**
- What is `mongod` and what is its role? — `mongod` is the core MongoDB database process responsible for handling client data requests, managing on-disk data storage, and performing background operations like replication.
- How would you install and start MongoDB locally on your OS of choice? — On macOS, MongoDB can be installed via Homebrew with `brew tap mongodb/brew`, `brew install mongodb-community@7.0`, and started with `brew services start mongodb-community@7.0`; other OSes provide equivalent package manager installs or Docker images.
- What are common configuration options you would set for a production `mongod` instance? — Common production settings include the data directory path (`storage.dbPath`), bind IP and port (`net.bindIp`, `net.port`), enabling authentication (`security.authorization`), and the replica set name (`replication.replSetName`).

## MongoDB Shell (mongosh)

`mongosh` is the modern, official command-line shell for interacting with MongoDB, offering a JavaScript-based REPL for running queries, administrative commands, and scripts. It replaced the legacy `mongo` shell and adds improved syntax highlighting, auto-completion, and better error messages. It's commonly used for ad-hoc queries, debugging, and running maintenance scripts.

```javascript
mongosh "mongodb://localhost:27017"
show dbs
use myAppDb
db.users.find({ age: { $gt: 25 } }).limit(5)
```

**Interview Questions:**
- What is `mongosh` and how does it differ from the legacy `mongo` shell? — `mongosh` is the modern, official JavaScript-based command-line shell for MongoDB, replacing the legacy `mongo` shell with improved syntax highlighting, auto-completion, and clearer error messages.
- How do you connect to a remote MongoDB instance using `mongosh`? — You connect by passing a connection string URI, such as `mongosh "mongodb://<host>:27017"` or an Atlas SRV connection string with credentials, to the `mongosh` command.
- What are some common `mongosh` commands you use for troubleshooting? — Common troubleshooting commands include `show dbs`, `use <db>`, `db.collection.find()`, `db.collection.explain()`, and `db.serverStatus()` to inspect data, query plans, and server health.

## MongoDB Compass

MongoDB Compass is the official GUI application for visually exploring databases, collections, and documents, building and testing queries and aggregation pipelines, analyzing schema, and monitoring index/query performance. It's especially useful for developers who prefer a visual interface over the shell for exploring unfamiliar datasets or building complex aggregation pipelines interactively.

**Advantages:**
- Visual schema analysis and index recommendations
- Interactive aggregation pipeline builder with stage-by-stage preview
- Built-in performance/explain plan visualization

**Disadvantages:**
- Not scriptable like `mongosh` for automation
- Adds a GUI dependency not suited for headless/server environments

**Interview Questions:**
- What is MongoDB Compass used for? — Compass is the official GUI for visually exploring databases, collections, and documents, building and testing queries and aggregation pipelines, and analyzing schema and index/query performance.
- How can Compass help when designing or debugging an aggregation pipeline? — Compass provides an interactive pipeline builder that shows stage-by-stage output previews, making it easier to iteratively construct and debug complex aggregation pipelines visually.
- What are the limitations of using Compass compared to the shell for automation? — Compass is not scriptable like `mongosh`, so it can't be used for automated tasks or CI/CD scripts, and it adds a GUI dependency unsuited for headless server environments.

## MongoDB Atlas (Overview)

MongoDB Atlas is the official fully managed Database-as-a-Service offering from MongoDB Inc., available on AWS, Azure, and GCP. It handles provisioning, patching, backups, monitoring, and scaling of clusters, while providing additional managed features like Atlas Search, Atlas Data Federation, and Atlas Triggers. Atlas is commonly used to avoid operational overhead of self-managing replica sets and sharded clusters.

**Advantages:**
- No infrastructure management; automated backups and patching
- Built-in monitoring, alerting, and performance advisor
- Global cluster support for multi-region deployments

**Disadvantages:**
- Ongoing subscription cost versus self-hosted
- Less control over low-level server configuration

**Interview Questions:**
- What is MongoDB Atlas and what problems does it solve? — Atlas is MongoDB's fully managed Database-as-a-Service, available on AWS, Azure, and GCP, that eliminates the operational overhead of provisioning, patching, backing up, and scaling self-managed replica sets and sharded clusters.
- What managed features does Atlas provide beyond a plain MongoDB server? — Atlas provides automated backups and patching, built-in monitoring/alerting and a performance advisor, global multi-region cluster support, and additional services like Atlas Search, Data Federation, and Triggers.
- What trade-offs exist between self-hosting MongoDB and using Atlas? — Self-hosting offers more control over low-level server configuration but requires operational effort for provisioning and maintenance, while Atlas removes that burden at the cost of an ongoing subscription fee and reduced low-level control.

## Configuration Basics

MongoDB server configuration is typically defined in a YAML file (commonly `mongod.conf`) covering settings such as `storage.dbPath`, `net.port`, `net.bindIp`, `security.authorization`, and `replication.replSetName`. Configuration can also be overridden via command-line flags when starting `mongod`. Properly securing configuration (enabling authentication, restricting bind IP, enabling TLS) is critical before exposing a MongoDB instance beyond localhost.

```yaml
# mongod.conf example
storage:
  dbPath: /var/lib/mongodb
net:
  port: 27017
  bindIp: 127.0.0.1
security:
  authorization: enabled
replication:
  replSetName: rs0
```

**Interview Questions:**
- What are the key sections of a `mongod.conf` file? — Key sections include `storage` (e.g., `dbPath`), `net` (port and bindIp), `security` (authorization), and `replication` (replSetName), each configuring a different aspect of the server.
- How do you enable authentication/authorization on a MongoDB instance? — Authentication/authorization is enabled by setting `security.authorization: enabled` in the config file (or the `--auth` flag), which requires clients to authenticate with valid credentials before performing operations.
- Why is restricting `bindIp` important for security? — Restricting `bindIp` limits which network interfaces `mongod` listens on, preventing the instance from being reachable over public or untrusted networks, which reduces the attack surface if authentication is misconfigured.

## MongoDB Drivers

MongoDB provides official drivers for many languages (Java, Node.js, Python, C#, Go, etc.) that translate native language calls into wire-protocol operations against the server. In the Java/Spring ecosystem, Spring Data MongoDB builds on the underlying MongoDB Java driver to provide repository abstractions, `MongoTemplate`, and object mapping between POJOs and BSON documents.

```java
@Document(collection = "users")
public class User {
    @Id
    private String id;
    private String name;
    private String email;
}

public interface UserRepository extends MongoRepository<User, String> {
    List<User> findByEmail(String email);
}
```

**Interview Questions:**
- What is the role of a MongoDB driver in an application? — A MongoDB driver translates native language calls into MongoDB's wire protocol operations, handling connection pooling, serialization/deserialization between language objects and BSON, and communication with the server.
- How does Spring Data MongoDB relate to the underlying MongoDB Java driver? — Spring Data MongoDB is a higher-level abstraction built on top of the MongoDB Java driver, providing repository interfaces, `MongoTemplate`, and object mapping between POJOs and BSON documents, while the driver handles the low-level wire protocol communication.
- What is the difference between using `MongoRepository` and `MongoTemplate` in Spring Data MongoDB? — `MongoRepository` provides a declarative, interface-based approach with derived query methods for common CRUD operations, while `MongoTemplate` offers a lower-level, imperative API giving finer control over queries, updates, and aggregation pipelines.

## MongoDB Atlas Search (Overview)

Atlas Search is a full-text search capability built directly into MongoDB Atlas, powered by Apache Lucene, that allows rich text search (fuzzy matching, relevance scoring, autocomplete, faceting) without needing a separate search engine like Elasticsearch. Search indexes are defined separately from regular MongoDB indexes and queried using the `$search` aggregation stage.

```javascript
db.products.aggregate([
  {
    $search: {
      text: {
        query: "wireless headphones",
        path: "description"
      }
    }
  }
])
```

**Interview Questions:**
- What is Atlas Search and what underlying technology powers it? — Atlas Search is a full-text search capability built into MongoDB Atlas, powered by Apache Lucene, enabling fuzzy matching, relevance scoring, autocomplete, and faceting without a separate search engine.
- How does the `$search` aggregation stage differ from a regular `$match` query? — `$search` leverages a dedicated Lucene-based search index to perform relevance-scored full-text search with features like fuzzy matching and autocomplete, whereas `$match` filters documents using standard MongoDB query operators against regular indexes without relevance scoring.
- When would you choose Atlas Search over a standalone search engine like Elasticsearch? — Atlas Search is preferable when you want full-text search capabilities integrated directly into your existing MongoDB Atlas cluster without operating and syncing a separate Elasticsearch deployment.
