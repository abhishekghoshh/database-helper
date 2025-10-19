# Apache Kafka - Complete Cheat Sheet

---

## 1️⃣ Topic

- A **topic** is a logical channel or category where producers send records and consumers read them.
- Topics are the main way Kafka organizes data streams.
- Each topic can have multiple **partitions** for scalability.
- Records in a topic consist of:
    - **Key** (optional): Used for partitioning and message grouping.
    - **Value** (payload): The actual data/message.
    - **Offset**: Unique position of the record within a partition.
- Topics can be configured for **retention** (how long data is kept) and **compaction** (keeping only the latest value per key).
- Topics are **append-only**; records cannot be updated or deleted after being written.

> **Example:** An `orders` topic collects all order events from an e-commerce platform.

---

## 2️⃣ Consumer Group

- A **consumer group** is a set of consumers that work together to read data from a topic.
- Kafka ensures that each partition in a topic is consumed by only one consumer within a group, enabling **parallel processing** and **load balancing**.
- Multiple consumer groups can read the same topic independently, allowing different applications to process the same data in their own way.
- Consumer groups provide **fault tolerance**: if one consumer fails, another in the group can take over.
- Consumers in a group coordinate their progress using **offsets**.

> **Example:** A group of analytics services consuming the `orders` topic, each processing a subset of the data.

---

## 3️⃣ Partition

- Topics are split into **partitions**, which are the basic unit of parallelism and scalability in Kafka.
- Each partition is:
    - **Ordered**: Records are stored in the order they arrive.
    - **Immutable**: Once written, records cannot be changed.
    - **Identified**: By `<topic>-<partition_number>`.
- Partitions allow Kafka to distribute data across multiple brokers and scale horizontally.
- More partitions mean higher throughput, but also more overhead for management and coordination.

> **Example:** The `orders` topic might have 6 partitions, allowing 6 consumers to process data in parallel.

---

## 4️⃣ Replication

- Kafka replicates each partition across multiple brokers for **high availability** and **durability**.
- One broker acts as the **leader** for a partition; others are **followers**.
- Producers and consumers interact only with the leader.
- If the leader fails, a follower is automatically promoted to leader, ensuring no data loss.
- Replication factor is configurable per topic.

> **Example:** A partition with replication factor 3 is stored on three brokers.

---

## Offset

- An **offset** is a unique, sequential number assigned to each record within a partition.
- Offsets allow consumers to track their progress and resume processing after failures.
- Offsets are managed per partition and per consumer group.
- Consumers can commit offsets manually or automatically.
- Offsets enable features like **replay** (reprocessing old data) and **exactly-once** or **at-least-once** delivery semantics.

> **Example:** Consumer group A has processed up to offset 100 in partition 2.

---

## 5️⃣ Routing Records (Odd/Even Example)

- Producers can control which partition a record goes to by specifying a key or using a custom partitioner.
- This enables routing logic, such as sending odd numbers to one partition and even numbers to another.
- Consumers can be assigned to specific partitions to process only the relevant data.

**Producer Example:**
```java
int partition = (number % 2 == 0) ? 1 : 0;
ProducerRecord<String, String> record =
        new ProducerRecord<>("numbers", partition, null, String.valueOf(number));
producer.send(record);
```

**Consumer Example:**
```java
KafkaConsumer<String, String> oddConsumer = new KafkaConsumer<>(props);
oddConsumer.assign(List.of(new TopicPartition("numbers", 0))); // Odd partition

KafkaConsumer<String, String> evenConsumer = new KafkaConsumer<>(props);
evenConsumer.assign(List.of(new TopicPartition("numbers", 1))); // Even partition
```

> **Use case:** Targeted processing, filtering, or sharding of data streams.

---

## 6️⃣ Change Data Capture (CDC)

- **CDC** is a technique for capturing changes (INSERT, UPDATE, DELETE) in databases and streaming them into Kafka topics.
- Enables real-time data synchronization between databases and other systems.
- Common CDC tools:
    - **Debezium**: Open-source, supports MySQL, PostgreSQL, MongoDB, SQL Server, Oracle, etc.
    - **Kafka Connect CDC connectors**.
- Use cases:
    - Replicating database changes to analytics platforms.
    - Building event-driven architectures.
    - Maintaining audit logs and data lineage.

---

## 7️⃣ Kafka Connect

- **Kafka Connect** is a framework for integrating Kafka with external systems (databases, files, cloud storage, etc.).
- Provides **source connectors** (import data into Kafka) and **sink connectors** (export data from Kafka).
- Connectors are configurable and scalable, supporting distributed deployments.
- Enables building ETL pipelines without custom code.
- Supports transformations and error handling.

> **Example:** Use Kafka Connect to stream data from MySQL into Kafka, then from Kafka to Elasticsearch.

---

## 8️⃣ Schema Registry

- The **Schema Registry** manages schemas for Kafka messages (Avro, JSON, Protobuf).
- Ensures producers and consumers agree on message structure, preventing data corruption.
- Supports **schema evolution** (backward/forward compatibility).
- Enforces rules to prevent breaking changes.
- Integrates with Kafka clients for automatic serialization/deserialization.

> **Example:** Enforce Avro schema for all messages in the `orders` topic.

---

## 9️⃣ ZooKeeper & KRaft

### ZooKeeper (legacy)
- Kafka originally used **ZooKeeper** for cluster metadata, broker management, and controller election.
- Required a separate ZooKeeper cluster, adding operational complexity.

### KRaft (Kafka Raft mode)
- Modern Kafka (2.8+) uses **KRaft** (Kafka Raft) mode, eliminating ZooKeeper.
- Stores metadata in internal Kafka topics.
- Simplifies deployment, improves scalability and resilience.
- New Kafka clusters should use KRaft mode.

---

## 🔟 Additional Features

- **Log Compaction**: Retains only the latest value per key, useful for stateful applications.
- **Exactly-Once Semantics (EOS)**: Guarantees that each message is processed only once, even in failure scenarios.
- **Streams API**: Enables building real-time, stateful stream processing applications directly on Kafka.
- **Kafka Admin API**: Programmatically manage topics, configurations, and access controls (ACLs).
- **Security**: Supports SSL, SASL, and ACLs for authentication and authorization.
- **Monitoring**: Exposes metrics via JMX and integrates with monitoring tools.

---

## 🔥 Kafka Use Cases

- **Real-time analytics**: Process and analyze data streams instantly for dashboards and alerts.
- **Event sourcing**: Store all changes as a sequence of events for audit and recovery.
- **Log aggregation**: Centralize logs from multiple services for troubleshooting and monitoring.
- **Messaging**: Decouple producers and consumers for scalable, resilient architectures.
- **Data integration**: Move data between databases, caches, search engines, and cloud services.
- **Microservices communication**: Enable asynchronous, reliable communication between services.

---

## 🛠️ Useful Kafka CLI Commands

```sh
# List topics
kafka-topics.sh --list --bootstrap-server localhost:9092

# Create a topic
kafka-topics.sh --create --topic my-topic --partitions 3 --replication-factor 2 --bootstrap-server localhost:9092

# Describe a topic
kafka-topics.sh --describe --topic my-topic --bootstrap-server localhost:9092

# Produce messages
kafka-console-producer.sh --topic my-topic --bootstrap-server localhost:9092

# Consume messages
kafka-console-consumer.sh --topic my-topic --from-beginning --bootstrap-server localhost:9092

# List consumer groups
kafka-consumer-groups.sh --list --bootstrap-server localhost:9092

# Describe consumer group offsets
kafka-consumer-groups.sh --describe --group my-group --bootstrap-server localhost:9092
```

---

## 📚 References

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kafka Quickstart Guide](https://kafka.apache.org/quickstart)
- [Debezium CDC](https://debezium.io/)
- [Confluent Schema Registry](https://docs.confluent.io/platform/current/schema-registry/index.html)
- [Kafka Connectors Hub](https://www.confluent.io/hub/)

---

> **Tip:** Monitor Kafka cluster health, tune configurations, and secure your deployment for optimal performance and reliability.

