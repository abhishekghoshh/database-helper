# Concepts for Spring Data MongoDB

## Object-Document Mapping (ODM)

Object-Document Mapping is the process Spring Data MongoDB uses to automatically convert between Java objects (POJOs annotated with `@Document`) and BSON documents stored in MongoDB. The `MappingMongoConverter` handles this translation, using field names, type information, and custom converters to map Java types to their BSON representation and back.

```java
@Document(collection = "orders")
public class Order {
    @Id
    private String id;
    private String customerName;
    private BigDecimal total;
    private List<OrderItem> items;
    // getters/setters
}
```

**Interview Questions:**
- How does Spring Data MongoDB convert between a Java object and a BSON document? — It uses `MappingMongoConverter`, which inspects the entity's fields and type metadata (via reflection and the mapping context) to serialize Java properties into BSON fields on write and reconstruct Java objects from BSON documents on read.
- What is `MappingMongoConverter` and when would you register a custom converter? — `MappingMongoConverter` is the default converter Spring Data MongoDB uses for object-document mapping; you'd register a custom `Converter<S, T>` bean when you need special handling for a type the default converter can't map correctly, such as a third-party class or a custom value representation.

## Entity vs Document

In Spring Data MongoDB terminology, an "entity" is the Java class representing your domain model, while a "document" is the actual BSON representation stored in MongoDB. The `@Document` annotation marks a Java class as mapped to a MongoDB collection, and field-level annotations (`@Field`, `@Id`) fine-tune how entity properties map to document fields.

```java
@Document(collection = "products")
public class Product {
    @Id
    private String id;

    @Field("product_name")
    private String name;
}
```

**Interview Questions:**
- What is the purpose of the `@Document` annotation and what happens if you omit the collection name? — `@Document` marks a class as mapped to a MongoDB collection; if you omit the `collection` attribute, Spring Data MongoDB derives the collection name automatically from the (decapitalized) class name.
- How would you map a Java field name to a differently named document field? — Annotate the field with `@Field("document_field_name")` to override the default (which otherwise uses the Java field name as-is) with a custom BSON field name.

## Mapping Nested Documents

Nested Java objects (POJOs referenced as fields) are automatically mapped by Spring Data MongoDB into embedded BSON sub-documents, without requiring any special annotation — this naturally models the embedding pattern for one-to-few relationships.

```java
public class Address {
    private String street;
    private String city;
}

@Document(collection = "customers")
public class Customer {
    @Id
    private String id;
    private String name;
    private Address address; // embedded as a nested document
}
```

```json
{ "_id": "c1", "name": "Jane", "address": { "street": "1 Main St", "city": "NYC" } }
```

**Interview Questions:**
- How does Spring Data MongoDB decide whether to embed a nested object versus store a reference? — By default, any plain nested POJO field is embedded as a sub-document; it's only stored as a reference if explicitly annotated with `@DBRef`, so embedding is the default behavior and referencing is opt-in.
- What happens when you query using a property path into a nested document (e.g. `address.city`)? — Spring Data MongoDB translates the dotted property path into a MongoDB dot-notation query filter (e.g. `{"address.city": "NYC"}`), which can use an index created on that nested field path.

## Mapping Collections

Java `List`/`Set`/arrays of simple types or nested objects are mapped directly to BSON arrays. Spring Data MongoDB also supports mapping a `Map<String, T>` to a BSON sub-document with dynamic keys, useful for the Attribute Pattern.

```java
@Document(collection = "products")
public class Product {
    @Id
    private String id;
    private List<String> tags;
    private Map<String, Object> attributes;
}
```

**Interview Questions:**
- How would you map a Java `Map` field to a MongoDB document and what are the query implications? — Spring Data MongoDB maps a `Map<String, T>` field directly to a BSON sub-document keyed by the map keys; querying specific entries requires dot notation (e.g. `"attributes.color"`), and dynamic/unknown keys make it harder to build simple indexes compared to a fixed-schema field.
- What are the trade-offs of storing a `List<NestedObject>` versus a separate referenced collection? — An embedded list is read atomically with the parent and avoids extra queries but grows the parent document and can hit size/performance limits at scale, while a separate collection keeps the parent small and allows independent querying/pagination at the cost of an extra lookup.

## Embedded Documents vs References

Spring Data MongoDB does not provide a native "join" like JPA — relationships modeled with `@DBRef` (or manually stored ID fields) require an additional query or `$lookup` aggregation stage, whereas embedded objects are fetched as part of the parent document with zero extra queries.

**Differences:**

| Aspect | Embedded Document | `@DBRef` / Manual Reference |
|---|---|---|
| Fetch cost | Included in parent read | Extra query per reference (lazy or eager) |
| Data consistency | Duplicated if repeated across parents | Single source of truth |
| Transactions needed for updates | No (atomic within document) | Yes, for multi-document consistency |
| Recommended for | 1-to-few, tightly coupled data | 1-to-many/many-to-many, independently managed entities |

```java
// @DBRef reference example (generally discouraged in favor of manual ID + repository lookup)
@Document(collection = "orders")
public class Order {
    @Id
    private String id;

    @DBRef
    private Customer customer;
}
```

**Interview Questions:**
- Why is `@DBRef` generally discouraged in favor of manually storing an ID and querying explicitly? — `@DBRef` incurs an extra query per reference (or per document when eagerly resolving collections, causing N+1 query problems), lacks fine-grained control over fetching, and doesn't support projections, whereas manually storing an ID field and querying the referenced repository directly is more explicit, efficient, and controllable.
- What are the performance implications of lazy `@DBRef` resolution? — Lazy resolution defers the extra query until the referenced field is actually accessed via a proxy, which avoids unnecessary fetches but can trigger a query outside the expected transactional/session context, and still results in one query per reference when accessed, risking N+1 behavior for collections.

## ObjectId Mapping

MongoDB's native `ObjectId` type can be mapped directly to a Java `org.bson.types.ObjectId` field, or converted to/from a `String` when annotated with `@Id` on a `String` field — Spring Data MongoDB handles the conversion automatically as long as the `String` value is a valid 24-character hex ObjectId.

```java
@Document(collection = "orders")
public class Order {
    @Id
    private String id; // stored as ObjectId in MongoDB, exposed as String in Java
}
```

**Interview Questions:**
- How does Spring Data MongoDB convert between `ObjectId` and a Java `String` `@Id` field? — The `MappingMongoConverter` automatically converts a MongoDB `ObjectId` to its 24-character hex string representation when reading into a `String`-typed `@Id` field, and converts it back to an `ObjectId` when writing, as long as the string is valid ObjectId hex.
- What happens if you assign a non-ObjectId-format string to an `@Id` field? — Spring Data MongoDB stores the value as a plain `String` (not converted to `ObjectId`) since it isn't valid 24-character hex, which is how custom/business-key string IDs are supported.

## Custom ID Strategies

Instead of relying on MongoDB's auto-generated `ObjectId`, applications can define custom identifier strategies — using a business key (e.g. SKU, email), a UUID, or an application-managed sequence (simulated via a counters collection, since MongoDB has no native auto-increment).

```java
@Document(collection = "products")
public class Product {
    @Id
    private String sku; // business key used as the identifier instead of ObjectId
}
```

**Interview Questions:**
- How would you implement an auto-incrementing numeric ID in MongoDB, given it has no native sequence support? — Maintain a separate "counters" collection with one document per sequence name, and use `findAndModify` with `$inc` to atomically increment and retrieve the next value each time a new ID is needed.
- What are the trade-offs of using a business key as `_id` versus a generated `ObjectId`? — A business key avoids a lookup/join to translate between identifiers and can be more meaningful, but risks needing to change if the business key changes (which is difficult since `_id` is immutable), while a generated `ObjectId` is guaranteed unique and stable but meaningless outside the database.

## Optimistic Locking Concepts

Spring Data MongoDB supports optimistic locking via the `@Version` annotation: on each update, the driver checks that the version field in the database still matches the version in the entity being saved, and increments it. If another process updated the document in the meantime, an `OptimisticLockingFailureException` is thrown, preventing lost updates.

```java
@Document(collection = "accounts")
public class Account {
    @Id
    private String id;

    @Version
    private Long version;

    private BigDecimal balance;
}
```

**Advantages:**
- Prevents lost updates without holding database locks
- Lightweight compared to pessimistic locking

**Disadvantages:**
- Requires the application to handle retries on version conflicts
- Only protects the single document carrying the `@Version` field

**Interview Questions:**
- How does `@Version`-based optimistic locking work in Spring Data MongoDB? — A field annotated `@Version` is checked on every update: Spring Data MongoDB includes the current version value in the update's query filter and increments it, so the update only succeeds if no other process has modified (and incremented) the document since it was read.
- What exception is thrown on a version conflict and how should the application handle it? — An `OptimisticLockingFailureException` is thrown when the version check fails; the application should typically catch it, reload the latest document, reapply the intended change, and retry the save.
- How does optimistic locking compare to using MongoDB transactions for concurrency control? — Optimistic locking is lightweight and lock-free, only protecting a single document via version checks, whereas multi-document transactions provide full ACID guarantees across multiple documents/collections at the cost of higher latency and resource overhead from holding locks during the transaction.

## Auditing Concepts

Spring Data MongoDB's auditing support (`@CreatedDate`, `@LastModifiedDate`, `@CreatedBy`, `@LastModifiedBy`) automatically populates timestamp and user-tracking fields when documents are inserted or updated, once `@EnableMongoAuditing` is enabled on a configuration class.

```java
@Configuration
@EnableMongoAuditing
public class MongoConfig { }

@Document(collection = "orders")
public class Order {
    @Id
    private String id;

    @CreatedDate
    private Instant createdAt;

    @LastModifiedDate
    private Instant updatedAt;
}
```

**Interview Questions:**
- What annotation enables automatic auditing support in a Spring Boot application? — `@EnableMongoAuditing` on a `@Configuration` class enables Spring Data MongoDB's auditing infrastructure, allowing `@CreatedDate`, `@LastModifiedDate`, `@CreatedBy`, and `@LastModifiedBy` fields to be populated automatically.
- How would you populate `@CreatedBy`/`@LastModifiedBy` with the current authenticated user? — Provide a bean implementing `AuditorAware<T>` whose `getCurrentAuditor()` method returns the current user (e.g. from Spring Security's `SecurityContextHolder`), which Spring Data MongoDB uses automatically to populate those fields.

## Lazy vs Eager References (Concept)

When using `@DBRef(lazy = true)`, Spring Data MongoDB returns a proxy object for the referenced entity and only issues the query to fetch it when a property is first accessed, deferring the cost. Eager (default) `@DBRef` resolves the reference immediately when the parent document is loaded.

**Differences:**

| Aspect | Eager `@DBRef` (default) | Lazy `@DBRef(lazy = true)` |
|---|---|---|
| Fetch timing | Immediately with parent | On first access via proxy |
| Extra queries | Always incurred | Only if referenced object is actually used |
| Risk | N+1 queries when loading collections of parents | `LazyInitializationException`-style issues outside a session/proxy context |

**Interview Questions:**
- What is the difference between lazy and eager `@DBRef` resolution? — Eager (default) `@DBRef` fetches the referenced document immediately when the parent is loaded, while `@DBRef(lazy = true)` returns a proxy that only triggers the fetch query when a property on the referenced object is first accessed.
- Why is `@DBRef` (lazy or eager) generally less recommended than manual reference resolution in Spring Data MongoDB? — Both variants incur per-reference queries that can cause N+1 query problems when loading collections of parents, offer no projection/batching control, and lazy proxies can behave unexpectedly outside their originating context, so manually storing an ID and querying the target repository explicitly (optionally batched) is usually more predictable and efficient.

## Repository Pattern (Concept)

Spring Data MongoDB's repository abstraction (`MongoRepository`) lets you define an interface and get CRUD and query-derivation methods (e.g. `findByCustomerNameAndStatus`) generated automatically at runtime, without writing implementation code. For queries that don't fit method-name derivation, `@Query` with a raw MongoDB query string can be used.

```java
public interface OrderRepository extends MongoRepository<Order, String> {
    List<Order> findByCustomerNameAndStatus(String customerName, String status);

    @Query("{ 'total': { $gte: ?0 } }")
    List<Order> findOrdersAboveTotal(BigDecimal minTotal);
}
```

**Interview Questions:**
- How does Spring Data MongoDB generate query implementations from repository method names? — It parses the method name at startup according to Spring Data's keyword conventions (e.g. `findBy`, `And`, `OrderBy`), builds a corresponding `Criteria`/`Query` object matching those keywords to the entity's fields, and generates a proxy implementation that executes that query at runtime.
- When would you use `@Query` instead of a derived query method? — Use `@Query` when the desired query is too complex to express via method-name derivation (e.g. nested operators, complex `$or`/`$and` combinations, or projections) or when a raw MongoDB query string is clearer and easier to maintain than a long derived method name.

## MongoTemplate (Concept)

`MongoTemplate` is the lower-level, imperative API in Spring Data MongoDB, offering full control over queries, updates, and aggregations using the `Query`/`Criteria` and `Aggregation` builder classes. It's used when repository method derivation isn't expressive enough, or when building queries dynamically at runtime.

```java
Query query = new Query(Criteria.where("status").is("active").and("total").gte(new BigDecimal("100")));
List<Order> orders = mongoTemplate.find(query, Order.class);

Update update = new Update().set("status", "shipped");
mongoTemplate.updateFirst(query, update, Order.class);
```

**Differences:**

| Aspect | `MongoRepository` | `MongoTemplate` |
|---|---|---|
| Style | Declarative (interface + derived/`@Query` methods) | Imperative (explicit Query/Update/Aggregation objects) |
| Best for | Standard CRUD and simple queries | Dynamic/complex queries built at runtime, bulk operations, aggregations |
| Boilerplate | Minimal | More verbose but more flexible |

**Interview Questions:**
- When would you choose `MongoTemplate` over a `MongoRepository` interface? — Choose `MongoTemplate` when you need to build queries dynamically at runtime (unknown combinations of filters), perform bulk operations, run aggregations, or need finer control than derived/`@Query` methods can express.
- How would you build a dynamic query with an unknown number of optional filter criteria using `MongoTemplate`? — Build a `Criteria` list conditionally, adding a criterion only if the corresponding filter parameter is present, then combine them with `new Criteria().andOperator(...)` (or start from an empty `Query` and call `.addCriteria()` for each present filter) before passing the resulting `Query` to `mongoTemplate.find()`.

## Aggregation Pipeline Concepts

Spring Data MongoDB exposes the native aggregation framework through the `Aggregation` builder class, letting you compose stages (`match`, `group`, `project`, `lookup`, `sort`, `unwind`) in type-safe Java code that gets translated into the equivalent MongoDB aggregation pipeline.

```java
Aggregation agg = Aggregation.newAggregation(
    Aggregation.match(Criteria.where("status").is("active")),
    Aggregation.group("customerId").sum("total").as("totalSpent"),
    Aggregation.sort(Sort.Direction.DESC, "totalSpent")
);

AggregationResults<CustomerSpend> results =
    mongoTemplate.aggregate(agg, "orders", CustomerSpend.class);
```

**Interview Questions:**
- How do you translate a raw MongoDB aggregation pipeline into Spring Data MongoDB's `Aggregation` builder API? — Map each pipeline stage to its corresponding static builder method (e.g. `$match` → `Aggregation.match()`, `$group` → `Aggregation.group()`, `$sort` → `Aggregation.sort()`) and chain them in order via `Aggregation.newAggregation(...)`, then execute with `mongoTemplate.aggregate()`.
- How would you perform the equivalent of a SQL join using Spring Data MongoDB's aggregation support? — Use `Aggregation.lookup()` to perform a `$lookup` stage joining another collection on a local/foreign field, typically followed by `Aggregation.unwind()` to flatten the resulting array into individual joined documents.

## Transactions with Spring Data MongoDB

Since MongoDB 4.0 (replica sets) and 4.2 (sharded clusters), multi-document ACID transactions are supported, and Spring Data MongoDB exposes them through `MongoTransactionManager` combined with Spring's standard `@Transactional` annotation, or programmatically via `TransactionTemplate`.

```java
@Configuration
public class MongoTransactionConfig {
    @Bean
    MongoTransactionManager transactionManager(MongoDatabaseFactory dbFactory) {
        return new MongoTransactionManager(dbFactory);
    }
}

@Service
public class TransferService {
    @Transactional
    public void transferFunds(String fromId, String toId, BigDecimal amount) {
        accountRepository.decrementBalance(fromId, amount);
        accountRepository.incrementBalance(toId, amount);
    }
}
```

**Advantages:**
- Guarantees atomicity across multiple documents/collections
- Familiar `@Transactional` programming model for developers coming from JPA

**Disadvantages:**
- Requires a replica set or sharded cluster (not standalone)
- Higher latency and lock contention compared to single-document atomic updates
- Long-running transactions can hold resources and hurt throughput

**Interview Questions:**
- What MongoDB deployment topology is required to use multi-document transactions? — Multi-document transactions require a replica set (available since MongoDB 4.0) or a sharded cluster (since MongoDB 4.2); standalone `mongod` instances do not support transactions.
- How do you configure `@Transactional` support for MongoDB in a Spring Boot application? — Define a `MongoTransactionManager` bean wired to your `MongoDatabaseFactory`, after which standard Spring `@Transactional` annotations on service methods will participate in MongoDB multi-document transactions.
- When should you prefer redesigning a schema to avoid needing a transaction versus actually using one? — Prefer redesigning the schema (e.g. embedding related data so updates are atomic within a single document) when the same logical operation is performed frequently and at scale, since single-document atomic updates are far cheaper than transactions; reserve transactions for genuinely cross-document operations that can't reasonably be modeled that way.

## Reactive MongoDB Support

Spring Data MongoDB provides a fully reactive, non-blocking API (`ReactiveMongoRepository`, `ReactiveMongoTemplate`) built on Project Reactor (`Mono`/`Flux`) and the reactive streams MongoDB driver, suited for reactive Spring WebFlux applications that need to avoid blocking threads while waiting on I/O.

```java
public interface ReactiveOrderRepository extends ReactiveMongoRepository<Order, String> {
    Flux<Order> findByStatus(String status);
}

@RestController
public class OrderController {
    @GetMapping("/orders/{status}")
    public Flux<Order> getOrders(@PathVariable String status) {
        return orderRepository.findByStatus(status);
    }
}
```

**Differences:**

| Aspect | `MongoRepository` (blocking) | `ReactiveMongoRepository` |
|---|---|---|
| Threading model | Blocking, one thread per request | Non-blocking, event-loop based |
| Return types | `List<T>`, `T`, `Optional<T>` | `Flux<T>`, `Mono<T>` |
| Best paired with | Spring MVC | Spring WebFlux |
| Transactions | `@Transactional` (imperative) | `ReactiveMongoTransactionManager` |

**Interview Questions:**
- What are the key differences between `MongoRepository` and `ReactiveMongoRepository`? — `MongoRepository` is blocking and returns standard types like `List<T>` and `Optional<T>` using one thread per request, while `ReactiveMongoRepository` is non-blocking, returns `Mono<T>`/`Flux<T>` backed by Project Reactor and the reactive streams driver, and is designed for event-loop-based frameworks like WebFlux.
- When would reactive MongoDB support provide a real throughput benefit versus the blocking API? — It helps most under high concurrency with I/O-bound workloads where many requests are waiting on the database simultaneously, since non-blocking I/O lets a small number of threads handle many concurrent requests without being tied up waiting; it offers little benefit for low-concurrency or CPU-bound workloads.
- How do you handle multi-document transactions in a reactive Spring Data MongoDB application? — Use `ReactiveMongoTransactionManager` combined with Spring's reactive transaction support (`@Transactional` on reactive return types, or `TransactionalOperator`) to wrap a sequence of reactive repository/template calls in a MongoDB transaction, which still requires a replica set or sharded cluster.
