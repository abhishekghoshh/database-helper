# Topic Management

### Topic Creation

Creating a topic establishes a new named log with a chosen partition count and replication factor, either explicitly via the admin CLI/API, or implicitly via **auto topic creation** (`auto.create.topics.enable=true`) when a producer or consumer references a topic that doesn't exist yet — a convenience most production teams disable in favor of explicit, reviewed topic provisioning (often via Infrastructure-as-Code/GitOps).

Key decisions at creation time include partition count (parallelism/throughput), replication factor (durability), and topic-level overrides for retention, cleanup policy, and min ISR — because while many settings can be changed later, partition count can only be increased (never decreased), making it worth planning carefully upfront.

In a Spring Boot application, topics can also be declared as beans using `NewTopic`/`TopicBuilder`, letting `KafkaAdmin` create them automatically at application startup — handy for local development and integration tests.

```java
@Configuration
public class KafkaTopicConfig {
    @Bean
    public NewTopic orderEventsTopic() {
        return TopicBuilder.name("order-events")
                .partitions(6)
                .replicas(3)
                .config(TopicConfig.RETENTION_MS_CONFIG, "604800000") // 7 days
                .build();
    }
}
```

```bash
kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic order-events --partitions 6 --replication-factor 3
```

**Real-life scenario:** A platform team disables `auto.create.topics.enable` in production and instead requires all topics to be created via a Terraform module reviewed in pull requests, preventing typo'd topic names from silently creating unmanaged, misconfigured topics.

**Interview Questions:**
- Why do many production teams disable auto topic creation? — To avoid accidental/misconfigured topics from typos and to enforce governance over partition/replication settings.
- Which topic setting cannot be decreased after creation? — Partition count.
- How can Spring Boot automatically create topics on startup? — By declaring `NewTopic` beans (e.g., via `TopicBuilder`), picked up by `KafkaAdmin`.

### Topic Configuration

Topics support a rich set of configuration overrides beyond partition count and replication factor, including `retention.ms`/`retention.bytes` (how long/how much data to keep), `cleanup.policy` (`delete` vs `compact` vs both), `min.insync.replicas`, `max.message.bytes`, `segment.ms`/`segment.bytes` (log segment rolling), and `compression.type`. These can be set at topic creation or altered later without downtime.

Topic-level configs override broker-level defaults, which lets teams apply broad sensible defaults cluster-wide (e.g., 7-day retention) while giving specific topics custom behavior (e.g., a compacted `user-profile-changelog` topic that never expires by time, only by compaction).

Understanding which configs are dynamic (changeable without restart, via `kafka-configs.sh --alter`) versus static (requiring broker restart) is a practical operational skill frequently probed in interviews.

```bash
# Alter topic config dynamically
kafka-configs.sh --bootstrap-server localhost:9092 \
  --entity-type topics --entity-name order-events \
  --alter --add-config retention.ms=259200000,min.insync.replicas=2
```

**Real-life scenario:** A team sets `cleanup.policy=compact` and disables time-based retention for a `customer-profile` topic so it behaves like a durable keyed changelog (latest state per customer ID), while their `clickstream` topic uses `cleanup.policy=delete` with a 3-day retention window.

**Interview Questions:**
- Can topic configuration be changed after the topic is created? — Yes, most configs (like retention, min ISR) can be altered dynamically without downtime.
- What's the difference between `retention.ms` and `retention.bytes`? — One limits retention by age, the other by total size per partition; whichever limit is hit first triggers deletion.
- Give an example of a topic-level override that differs from a sensible cluster default. — A compacted changelog topic overriding the cluster's default delete-based retention policy.

### Topic Partitions

(See also "Partitions" and "Topic Partitioning" above.) From a topic management perspective, partitions are the unit you provision and monitor per topic: you choose the initial count at creation, can only increase it later, and must track per-partition metrics (size, leader, ISR, consumer lag) as part of ongoing operations. Tools like `kafka-topics.sh --describe` and Kafka's JMX metrics expose per-partition leader/ISR/replica assignment for operational visibility.

A common operational task is **partition reassignment** — moving partitions between brokers (e.g., after adding new brokers, or to fix uneven load) using `kafka-reassign-partitions.sh`, which generates a reassignment plan and executes it as a background data-copy operation.

Choosing the right partition count up front matters because while you can add partitions later, doing so does not rebalance existing data across brokers automatically, and it changes the key-to-partition mapping for future records.

```bash
# Describe partitions, leaders, and ISR for a topic
kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic order-events
```

**Real-life scenario:** After onboarding three new brokers, an operations engineer uses `kafka-reassign-partitions.sh` to spread `order-events`' 12 partitions more evenly across all brokers, improving overall cluster throughput and balance.

**Interview Questions:**
- What tool is used to move partitions between brokers? — `kafka-reassign-partitions.sh`.
- Does adding partitions automatically rebalance existing data? — No, new partitions start empty; existing data isn't redistributed.
- What per-partition information does `kafka-topics.sh --describe` show? — Leader, replicas, and ISR set for each partition.

### Topic Replication

Topic replication management involves setting and monitoring the replication factor per topic, ensuring the ISR stays healthy, and performing partition reassignment when replication needs to change (e.g., increasing replication factor after the fact, or moving replicas off a decommissioned broker). Unlike simple config values, replication factor changes require generating and executing a reassignment plan because new replica copies must be created and fully synced before they can join the ISR.

Operationally, the most important replication health signals are `UnderReplicatedPartitions` (ISR smaller than replication factor) and `OfflinePartitionsCount` (partitions with no available leader) — both are near-universal alerting rules in production Kafka monitoring.

Cross-cluster replication (as opposed to intra-cluster replication) is a separate concern handled by tools like MirrorMaker 2 or Confluent's Cluster Linking, typically used for disaster recovery or multi-region active-active/active-passive setups.

```bash
# Generate and execute a partition reassignment (e.g., increase replication)
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --reassignment-json-file reassignment.json --execute
```

**Real-life scenario:** After a disk failure permanently takes a broker offline, an SRE runs a reassignment to move that broker's replicas to healthy brokers, restoring the topic's target replication factor and clearing the `UnderReplicatedPartitions` alert.

**Interview Questions:**
- What operation is required to change a topic's replication factor after creation? — A partition reassignment to add/remove replica copies.
- What metric indicates a topic partition currently has no leader? — `OfflinePartitionsCount` (a critical, page-worthy alert).
- What tools handle cross-cluster (as opposed to intra-cluster) replication? — MirrorMaker 2 or Cluster Linking.

### Topic Retention

Retention determines how long Kafka keeps records in a partition before eligible segments are deleted, controlled by `retention.ms` (time-based, default 7 days) and/or `retention.bytes` (size-based, per partition) — whichever limit is reached first triggers deletion of old log segments. Retention applies to topics using `cleanup.policy=delete` (as opposed to `compact`).

Retention is enforced at the **segment** level, not per individual record: Kafka rolls the active log into fixed-size or time-boxed segment files (`segment.bytes`/`segment.ms`), and only deletes whole segments once every record in them is past the retention threshold — meaning actual deletion can lag behind the theoretical retention window somewhat.

Setting retention too short risks losing data consumers haven't read yet (especially if a consumer is down for maintenance); setting it too long (or unbounded) risks unbounded disk growth. Retention of `-1` means "keep forever," typically only appropriate combined with compaction or for small, critical topics.

```bash
kafka-configs.sh --bootstrap-server localhost:9092 \
  --entity-type topics --entity-name clickstream --alter \
  --add-config retention.ms=259200000  # 3 days
```

**Real-life scenario:** A team shortens retention on a high-volume `clickstream` topic from 30 days to 3 days after confirming all downstream consumers process data within hours, cutting storage costs significantly.

**Interview Questions:**
- What are the two main levers controlling retention? — `retention.ms` (time) and `retention.bytes` (size), whichever is hit first.
- Is retention enforced per-record or per-segment? — Per-segment; whole segment files are deleted once expired.
- What risk does a very short retention window introduce? — Consumers that fall behind or are offline may miss data permanently.

### Topic Compaction

Log compaction is an alternative (or additional) cleanup policy (`cleanup.policy=compact`) that retains only the **latest record for each key** in a partition, rather than deleting based on age/size. This turns a Kafka topic into a durable, replayable changelog of "current state per key" — ideal for use cases like a `customers` topic where you only care about each customer's latest profile, not their full history of edits.

The compaction process runs in the background (the log cleaner threads), periodically rewriting segments to drop superseded records while preserving the relative offset order of surviving records. A special **tombstone** record (a key with a `null` value) signals deletion of that key; tombstones are themselves eventually removed after `delete.retention.ms`, once consumers have had a chance to see the deletion.

Compacted topics are the storage mechanism behind Kafka Streams' `KTable` and behind Kafka's own internal `__consumer_offsets` topic (which only needs the latest committed offset per group/partition, not full history).

```bash
kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic customer-profile-changelog \
  --partitions 6 --replication-factor 3 \
  --config cleanup.policy=compact --config min.cleanable.dirty.ratio=0.1
```

**Real-life scenario:** A `user-preferences` topic uses compaction so that after millions of updates over years, the topic still only physically stores one record per user ID — the latest preferences snapshot — dramatically reducing storage compared to keeping every historical update.

**Interview Questions:**
- What does log compaction guarantee about a partition's contents? — At least the latest record for every key is retained.
- How do you delete a key entirely from a compacted topic? — Publish a tombstone record (that key with a `null` value).
- What Kafka Streams concept is backed by compacted topics? — `KTable`, representing the latest value per key.

### Internal Topics

Kafka uses several **internal topics**, prefixed with double underscores, to store its own operational state — most notably `__consumer_offsets` (committed consumer group offsets, compacted) and `__transaction_state` (transactional producer state for exactly-once semantics, also compacted). In KRaft mode, `__cluster_metadata` similarly stores the cluster's own metadata log.

These topics are created automatically by the broker and are managed internally — you generally shouldn't produce/consume them directly in application code, though inspecting them (e.g., with `kafka-console-consumer.sh --formatter` for offsets) is a common and useful debugging technique.

Because `__consumer_offsets` and `__transaction_state` are compacted, they naturally stay bounded in size regardless of how long a cluster runs, since only the latest state per key (e.g., per consumer-group-partition) is retained.

```bash
# Inspect committed offsets (for debugging only)
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic __consumer_offsets --formatter \
  "kafka.coordinator.group.GroupMetadataManager\$OffsetsMessageFormatter" \
  --from-beginning
```

**Real-life scenario:** While debugging why a consumer group won't stop reprocessing data, an engineer inspects `__consumer_offsets` directly to confirm whether commits are actually landing for that group/partition.

**Interview Questions:**
- Name two important internal Kafka topics and what they store. — `__consumer_offsets` (committed offsets) and `__transaction_state` (transactional producer state).
- Why are internal topics like `__consumer_offsets` compacted rather than time-retained? — Because only the latest value per key (e.g., per group+partition) matters, keeping the topic bounded in size.
- Should application code produce directly to internal topics? — No, they are managed by the broker/clients internally, not meant for direct application use.

### Topic Deletion

Deleting a topic permanently removes its partitions, data, and configuration from the cluster, controlled by the broker-level `delete.topic.enable` setting (default `true` in modern Kafka). Because deletion is irreversible and immediate once processed, production clusters often protect topics via ACLs so only authorized automation/administrators can delete them.

Topic deletion is an asynchronous operation from the controller's perspective — it marks the topic for deletion and the brokers hosting its partitions clean up the underlying log segments in the background; very large topics may take some time to fully disappear from disk.

A frequent real-world gotcha: deleting and immediately recreating a topic with the same name can occasionally race with the deletion still finishing in the background, leading to confusing transient errors — a small delay or explicit verification is a safer operational pattern.

```bash
kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic old-events
```

**Real-life scenario:** A team decommissioning a deprecated microservice deletes its dedicated topic as part of cleanup, but first double-checks no other consumer groups are still subscribed, since deletion is irreversible and would cause silent data loss for any lingering consumer.

**Interview Questions:**
- What broker setting controls whether topic deletion is allowed? — `delete.topic.enable` (default `true`).
- Is topic deletion synchronous or asynchronous? — Asynchronous; the controller marks it for deletion and brokers clean up segments in the background.
- What precaution should you take before deleting a topic in production? — Confirm no active consumer groups or producers still depend on it, since deletion is irreversible.

### Minimum In-Sync Replicas (min.insync.replicas)

`min.insync.replicas` is a topic (or broker-default) configuration that sets the minimum number of replicas that must acknowledge a write (be part of the ISR) for a produce request with `acks=all` to succeed. It exists specifically to prevent a false sense of durability: without it, `acks=all` combined with a shrunk ISR (e.g., down to just the leader) would still "succeed" but with effectively zero redundancy.

A very common production pattern is replication factor 3 with `min.insync.replicas=2`: this tolerates one broker failure while still requiring at least 2 copies acknowledge every write, giving a solid balance between availability and durability. If ISR drops below `min.insync.replicas` (e.g., 2 brokers down), `acks=all` producers start receiving `NotEnoughReplicasException`, deliberately favoring consistency/durability over availability.

This setting is frequently paired with `acks=all` in interview questions about "how do you guarantee no data loss in Kafka," since neither setting alone is sufficient — you need both together.

```properties
# Topic config combined with producer acks=all for strong durability
min.insync.replicas=2
```

```java
config.put(ProducerConfig.ACKS_CONFIG, "all"); // combine with topic's min.insync.replicas=2
```

**Real-life scenario:** A payments team sets replication factor 3 and `min.insync.replicas=2` on their `transactions` topic; when two of three brokers hosting a partition go down simultaneously, writes are deliberately rejected rather than risk accepting transactions with no redundancy.

**Interview Questions:**
- What does `min.insync.replicas` protect against that `acks=all` alone does not? — Writes succeeding with a dangerously shrunk ISR (e.g., only the leader), losing real redundancy.
- What is a common production combination of replication factor and `min.insync.replicas`? — Replication factor 3 with `min.insync.replicas=2`.
- What exception do `acks=all` producers get when ISR falls below `min.insync.replicas`? — `NotEnoughReplicasException`.

