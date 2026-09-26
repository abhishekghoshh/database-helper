# Best Practices

### Topic Naming Conventions

Consistent topic naming conventions prevent chaos as a Kafka deployment grows from a handful of topics to hundreds across many teams. A common convention is `<domain>.<entity>.<event-type>` or `<team>.<system>.<entity>-<version>` (e.g. `orders.order.created`, `payments.invoice.paid.v1`), using lowercase, dot- or dash-separated segments, and avoiding special characters that complicate tooling.

Interviewers ask about this to see if you've worked in a real multi-team Kafka deployment, where topic sprawl and naming collisions are a genuine operational pain point. A good convention also encodes ownership and versioning, making it possible to apply consistent ACLs, quotas, and retention policies by prefix pattern.

**Real-life scenario:** A platform team enforces `<domain>.<entity>.<event>` naming via a topic-creation approval pipeline, so ACLs like `orders.*` can be granted to the orders team without accidentally exposing unrelated topics.

**Interview Questions**
- Why does topic naming matter at organizational scale, not just technically? — A consistent, predictable scheme prevents naming collisions across teams and enables applying ACLs, quotas, and retention policies by prefix pattern rather than managing every topic individually.
- How would you encode versioning into a topic name, and why? — Append a version suffix (e.g. `.v1`, `.v2`) so a breaking schema change can be introduced as a new topic without disrupting existing consumers of the old version.
- How can a naming convention simplify applying ACLs or quotas across many topics? — A predictable prefix (e.g. `orders.*`) lets you grant/restrict access or apply quotas to an entire domain's topics with a single wildcard rule instead of per-topic configuration.

### Partition Sizing

Partition sizing is about choosing the physical/logical size and count of partitions so that no single partition becomes a bottleneck (a "hot partition") while avoiding excessive per-partition overhead (each partition consumes broker memory/file handles and adds latency to metadata operations and leader elections). Guidance typically targets partitions in the range of a few hundred MB/s max throughput each in mind, and choosing a partition key that distributes load evenly to avoid skew.

Interviewers use this to test whether candidates think about "how much data/throughput per partition" rather than just "how many partitions total" — a topic with 100 partitions is still poorly sized if 90% of traffic hashes to 3 of them due to a skewed key (e.g. partitioning by `tenantId` when one tenant is 1000x larger than others).

**Real-life scenario:** A multi-tenant SaaS platform initially partitioned events by `tenantId`, causing one enterprise customer's traffic to overload a single partition; switching to a composite key (`tenantId + hash bucket`) spread the load evenly.

**Interview Questions**
- What is a "hot partition" and what typically causes one? — A partition receiving disproportionately more traffic than others, usually caused by a skewed partition key (e.g. one very active tenant/entity) so load isn't evenly distributed.
- Why doesn't simply adding more partitions always fix a throughput problem? — If the underlying key distribution is skewed, most traffic still hashes to the same few partitions regardless of total partition count, so the hot-partition bottleneck remains.
- How would you detect partition skew in a running cluster? — Monitor per-partition throughput/consumer-lag metrics and compare them across partitions of the same topic to spot ones receiving disproportionately more traffic.

### Choosing Replication Factor

Replication factor determines how many copies of each partition exist across the cluster, directly trading storage/network cost for fault tolerance. The near-universal production standard is `replication.factor=3`, which tolerates the loss of any one broker (or, with `min.insync.replicas=2` and `acks=all`, still guarantees durability while one replica is down) — `replication.factor=2` is sometimes used in cost-sensitive, less critical environments, but tolerates only very limited failure scenarios safely.

Interviewers expect a candidate to connect replication factor directly to `min.insync.replicas` and `acks`: setting `replication.factor=3` but `min.insync.replicas=1` still leaves you exposed to data loss on certain failure sequences, so these settings must be reasoned about together, not in isolation.

**Real-life scenario:** A team initially ran with `replication.factor=2` to save on storage costs, but after a broker failure caused a brief availability gap, they moved all critical topics to `replication.factor=3` with `min.insync.replicas=2`.

**Interview Questions**
- Why is `replication.factor=3` considered the standard for production Kafka topics? — It tolerates the loss of one broker while still maintaining at least 2 in-sync copies (with `min.insync.replicas=2`), balancing durability against storage/network overhead.
- How do `replication.factor` and `min.insync.replicas` interact to determine durability guarantees? — `replication.factor` is the total copy count; `min.insync.replicas` is the minimum number of those copies that must acknowledge a write (under `acks=all`) for it to be durable, so durability is really governed by the smaller, enforced threshold.
- What's the downside of a higher replication factor? — Increased storage usage, network bandwidth for replication, and slightly higher write latency, proportional to the number of extra copies maintained.

### Choosing Number of Partitions

Choosing partition count upfront requires balancing desired consumer parallelism (partitions ≥ expected max consumer instances) against per-partition overhead (too many partitions across many topics can strain broker memory, file handles, and controller metadata, and increase end-to-end latency due to more replication fan-out). A common heuristic is to size partitions based on target throughput divided by per-partition throughput capacity, then round up for headroom, while remembering partition count can be increased later but never decreased.

Interviewers like this topic because it requires weighing multiple factors simultaneously rather than reciting a single number — there's no universally "correct" partition count; it depends on target throughput, expected consumer scale-out, and ordering requirements.

**Real-life scenario:** A team sizing a new topic expecting to scale consumers up to 20 instances during peak load creates the topic with 20 partitions upfront, rather than needing a disruptive later increase that could break existing key-based ordering.

**Interview Questions**
- What factors go into choosing an initial partition count for a new topic? — Target throughput, expected maximum consumer group parallelism, and per-partition overhead on brokers, sized with some headroom since partition count can be increased but never decreased.
- Why might "just create the topic with 1000 partitions to be safe" be a bad idea? — Excess partitions increase broker memory/file-handle usage, controller metadata overhead, and can slow down leader elections and end-to-end latency, even if never fully utilized.
- How does expected consumer group size influence partition count decisions? — Partition count sets the ceiling on useful consumer parallelism, so it should be at least as large as the maximum number of consumer instances you expect to run concurrently.

### Message Size Best Practices

Kafka is optimized for high-throughput streams of relatively small messages, not large payloads; the default `message.max.bytes`/`max.request.size` are set conservatively (around 1MB), and pushing large messages (multi-MB images, files) through Kafka increases broker memory pressure, replication cost, and can hurt overall cluster throughput for all topics, not just the one with large messages. Best practice for large payloads is the "claim check" pattern: store the large payload in an external store (S3, blob storage) and publish only a reference/URL plus small metadata in the Kafka message.

Interviewers ask about this to see if a candidate understands Kafka's sweet spot and doesn't default to "just put everything in Kafka" — recognizing when an external store plus a lightweight event is architecturally better.

```json
{
  "orderId": "abc-123",
  "documentUrl": "s3://invoices/abc-123.pdf",
  "contentType": "application/pdf"
}
```

**Real-life scenario:** Instead of publishing full PDF invoices (several MB each) directly into a Kafka topic, a billing system uploads the PDF to S3 and publishes a small event containing just the `documentUrl`, keeping the topic lightweight and fast.

**Interview Questions**
- Why is Kafka not well-suited for transporting large binary payloads directly? — Large messages increase broker memory pressure, replication cost, and can degrade throughput for all topics sharing the cluster, since Kafka is tuned for high-volume small/medium messages, not bulk file transfer.
- What is the "claim check" pattern and when would you use it? — Storing the large payload in external storage (e.g. S3) and publishing only a small reference/URL plus metadata in the Kafka message; use it whenever payloads would otherwise be multi-MB (images, documents, files).
- What broker-side settings control the maximum allowed message size? — `message.max.bytes` (broker/topic level) and `max.request.size` (producer level), which must be aligned for large messages to be accepted end-to-end.

### Key Design

Message key design determines partition assignment (via `hash(key) % numPartitions` by default) and therefore both ordering guarantees and load distribution. A good key groups related messages that need relative ordering (e.g. all events for one `orderId`) while distributing overall load evenly across partitions — a key that's too coarse-grained (e.g. a single `tenantId` for a huge tenant) creates hot partitions, while `null` keys (round-robin) give even distribution but no ordering guarantee at all.

Interviewers use key design questions to probe whether a candidate can reason about the ordering-vs-distribution trade-off concretely, since it's one of the most consequential, hard-to-change decisions in a Kafka-based system (changing the key effectively reshuffles data across partitions).

```java
// good: groups all events for an order together, evenly distributed across many orders
kafkaTemplate.send("orders", order.getId(), event);
```

**Real-life scenario:** A ride-sharing platform keys trip-status events by `tripId` (evenly distributed across millions of trips) rather than by `driverId` (which could create hot partitions for very active drivers), preserving per-trip ordering without skew.

**Interview Questions**
- What determines which partition a keyed message is sent to by default? — The default partitioner hashes the record key (`hash(key) % numPartitions`) to deterministically pick a partition.
- Why might keying by a low-cardinality field (like `tenantId` for one huge tenant) be risky? — It can concentrate a disproportionate share of traffic onto the partition(s) that large tenant's key hashes to, creating a hot partition and uneven load.
- What ordering guarantee do you get with a `null` key? — None across messages — with a `null` key, the default partitioner distributes records round-robin (or via sticky partitioning) across partitions, so there's no guaranteed relative ordering between them.

### Consumer Group Design

Consumer group design is about deciding how many logically distinct consumer groups you need and how they map to partitions and application instances. Each independent "concern" (e.g. fraud detection, analytics, notifications) that needs its own full copy of a topic's data should be its own consumer group; instances that share work on the *same* concern should be in the *same* group (competing consumers). Group ID naming should also be stable across deployments — changing a `group.id` accidentally resets consumption to the configured `auto.offset.reset` policy, potentially causing reprocessing or data loss.

Interviewers ask about this to test operational awareness: a common real-world mistake is accidentally creating a new consumer group on every deployment (e.g. via a dynamically generated group ID), which silently resets offset tracking and can either skip a huge backlog or reprocess everything from the beginning.

**Real-life scenario:** A team's CI/CD pipeline accidentally appended a build timestamp to `group.id`, creating a brand-new consumer group on every deploy that defaulted to `latest` and silently skipped a growing backlog of unprocessed orders.

**Interview Questions**
- What's the risk of accidentally changing a consumer's `group.id` between deployments? — It creates a brand-new consumer group with no committed offset history, so it starts consuming according to `auto.offset.reset` (potentially skipping a huge backlog or reprocessing everything from the start).
- How do you decide whether two consumers should share a consumer group or use separate ones? — If they perform the same logical work and should split messages between them, use the same group (competing consumers); if each needs its own full copy of every message, use separate groups.
- How does `auto.offset.reset` behave for a brand-new consumer group versus an existing one? — For a brand-new group with no committed offsets, it determines the starting point (`earliest` or `latest`); for an existing group, it's ignored entirely since the group resumes from its last committed offset.

### Error Handling Best Practices

Robust Kafka error handling distinguishes **transient** failures (network blip, temporary downstream unavailability — worth retrying) from **permanent** failures (malformed message, business-rule violation — not worth retrying, should go straight to a dead-letter topic). Best practice combines bounded retries with backoff (`DefaultErrorHandler` + `ExponentialBackOffWithMaxRetries`), a dead-letter topic for exhausted/permanent failures, and structured logging/metrics on the failure so it's observable rather than silently swallowed.

Interviewers use this to see if a candidate avoids the two most common anti-patterns: catching and silently discarding exceptions in a listener (data loss with no trace) and retrying forever with no backoff (can amplify an outage and blocks partition progress).

```java
@Bean
public DefaultErrorHandler errorHandler(KafkaTemplate<Object, Object> template) {
    var backOff = new ExponentialBackOffWithMaxRetries(5);
    backOff.setInitialInterval(500L);
    backOff.setMultiplier(2.0);
    backOff.setMaxInterval(10_000L);
    var recoverer = new DeadLetterPublishingRecoverer(template);
    return new DefaultErrorHandler(recoverer, backOff);
}
```

**Real-life scenario:** After several incidents where a single malformed message silently blocked a partition for hours, a team standardizes on exponential-backoff retries plus dead-letter routing across every consumer in the organization.

**Interview Questions**
- Why is silently catching and logging an exception inside a `@KafkaListener` method often a bad pattern? — It commits the offset as if processing succeeded, permanently losing the message with only a log line as a trace, instead of retrying or routing it to a DLT for proper handling/visibility.
- How do you tell the difference between a retryable and a non-retryable error in a listener? — Classify by exception type — transient failures (timeouts, connection errors) are retryable; permanent failures (deserialization errors, validation exceptions) should be marked non-retryable and sent straight to a DLT.
- What's the benefit of exponential backoff over fixed-interval retries? — It gives a failing dependency progressively more time to recover between attempts, reducing the chance of amplifying an ongoing outage compared to hammering it at a constant fixed interval.

### Performance Best Practices

Kafka performance tuning spans producers, brokers, and consumers: on the producer side, batch (`batch.size`, `linger.ms`) and compress (`compression.type=lz4`/`zstd`); on the broker side, ensure adequate page cache, use fast disks, and avoid over-partitioning a single broker; on the consumer side, tune `fetch.min.bytes`/`max.poll.records` for batch efficiency and ensure processing logic inside the listener is fast (or offloaded asynchronously) so it doesn't stall the poll loop and trigger rebalances.

Interviewers ask broad performance questions to see if a candidate can reason across the whole pipeline rather than tuning just one side — e.g., a slow consumer can cause `max.poll.interval.ms` timeouts and unnecessary rebalances even if producers and brokers are perfectly tuned.

```properties
# producer
batch.size=32768
linger.ms=10
compression.type=lz4
acks=all

# consumer
fetch.min.bytes=1024
max.poll.records=500
max.poll.interval.ms=300000
```

**Real-life scenario:** A team diagnosed frequent consumer-group rebalances not as a Kafka bug but as a symptom of a slow downstream HTTP call inside the listener exceeding `max.poll.interval.ms`; moving the call to an async queue fixed the rebalancing storm.

**Interview Questions**
- What producer settings would you tune to increase throughput at the cost of a little latency? — Increase `linger.ms` and `batch.size` to accumulate larger batches, and enable compression (`compression.type=lz4`/`zstd`), trading a small amount of added latency for higher overall throughput.
- How can slow message processing inside a consumer cause unexpected rebalances? — If processing takes longer than `max.poll.interval.ms` between polls, the group coordinator considers the consumer dead and triggers a rebalance, even though the consumer is still alive and just slow.
- What's the trade-off of enabling stronger compression like `zstd` versus `lz4`? — `zstd` typically achieves a better compression ratio (smaller network/disk footprint) but uses more CPU than the faster, lighter-weight `lz4`.

