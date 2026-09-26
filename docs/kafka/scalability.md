# Scalability

### Horizontal Scaling

Horizontal scaling in Kafka means adding more machines/processes (brokers, producer instances, or consumer instances) to handle increased load, rather than making a single machine bigger (vertical scaling). Kafka's architecture is designed around this from the ground up: topics are split into partitions distributed across brokers, and consumer groups distribute partition consumption across many consumer instances — both scale by adding more units, not bigger units.

Interviewers ask about this broadly to see whether you understand that Kafka's scalability story is fundamentally partition-based: you cannot scale beyond the number of partitions for a given topic's consumption parallelism, and you cannot scale broker-level throughput beyond how partitions are distributed across the cluster. This makes partition count a first-class scaling decision made largely at topic-creation time (though it can be increased later, not decreased).

**Real-life scenario:** During a holiday sales spike, a platform team scales the order-processing consumer deployment from 3 to 12 pods (matching partition count) via Kubernetes HPA, linearly increasing throughput with no code changes.

**Interview Questions**
- Why is horizontal scaling generally preferred over vertical scaling for distributed systems like Kafka? — It avoids a single point of failure/bottleneck, scales cost roughly linearly, and matches Kafka's partition-distributed architecture, whereas vertical scaling hits hardware limits and doesn't improve fault tolerance.
- What's the hard upper limit on consumer parallelism for a single consumer group? — The number of partitions on the topic(s) being consumed — you cannot usefully run more active consumer instances than partitions.
- How would you scale a Kafka cluster to handle 10x the current message volume? — Add more brokers and rebalance partitions onto them, increase partition counts on high-throughput topics, and scale out producer/consumer instances accordingly, while tuning batching/compression settings.

### Scaling Producers

Producers scale largely for free: a single producer instance is already highly concurrent internally (it batches records, uses a background I/O thread, and can have multiple in-flight requests per connection via `max.in.flight.requests.per.connection`), and you can additionally run many producer instances/application replicas publishing concurrently since producers don't coordinate with each other. Tuning knobs like `batch.size`, `linger.ms`, and `compression.type` matter more for producer throughput than simply "adding more producers."

Interviewers use this to check whether you understand that producer scaling is mostly about **efficient batching and compression** rather than adding instances, and that partition count determines the ceiling on how much parallel write throughput a topic can accept across brokers.

```java
Properties props = new Properties();
props.put(ProducerConfig.BATCH_SIZE_CONFIG, 32 * 1024);
props.put(ProducerConfig.LINGER_MS_CONFIG, 10);
props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "lz4");
props.put(ProducerConfig.ACKS_CONFIG, "all");
```

**Real-life scenario:** Increasing `linger.ms` from 0 to 10ms lets a high-volume clickstream producer batch many small events together, cutting broker-side request overhead and increasing throughput significantly with negligible added latency.

**Interview Questions**
- How does `linger.ms` trade off latency for throughput? — A higher `linger.ms` delays sending a batch slightly to let more records accumulate, increasing batch size and throughput/efficiency at the cost of added per-message latency.
- Does adding more producer application instances always increase write throughput? Why or why not? — Not necessarily — total write throughput is ultimately capped by partition count and broker capacity, so beyond a point, more producer instances just contend for the same partitions without net gain.
- How does `compression.type` affect both producer CPU usage and network/broker load? — Compression (e.g. `lz4`, `zstd`) trades additional producer-side CPU for smaller network payloads and less broker disk/network I/O, generally improving overall throughput despite the added CPU cost.

### Scaling Consumers

Consumers scale by adding more instances to a consumer group, up to the number of partitions on the topics being consumed — Kafka's group coordinator automatically rebalances partition ownership across however many instances are alive. Beyond that hard limit, further scaling requires increasing partition count (which is a one-way, topic-level operation with ordering implications) or using multiple consumer groups for different concerns.

This is a favorite interview area because it connects several concepts: consumer group rebalancing protocol, partition-assignment strategies (`RangeAssignor`, `CooperativeStickyAssignor`), and the practical operational reality that over-provisioning idle consumer instances wastes resources without adding throughput.

```java
@KafkaListener(topics = "orders", groupId = "order-service", concurrency = "6")
public void listen(OrderEvent event) { /* ... */ }
```

**Real-life scenario:** A team notices consumer lag climbing under load and scales from 4 to 8 pods, but lag doesn't improve further past 8 because the topic only has 8 partitions — the extra pods sit idle until partition count is increased.

**Interview Questions**
- What happens when you add more consumer instances to a group than there are partitions? — The extra instances are assigned no partitions and remain idle, contributing nothing to throughput until partition count increases or another instance fails.
- How does `CooperativeStickyAssignor` reduce the disruption of rebalances compared to the eager `RangeAssignor`? — It only reassigns the specific partitions that need to move, letting unaffected consumers keep processing their existing partitions during a rebalance, instead of revoking all partitions from everyone first.
- If consumer lag keeps growing despite adding instances, what should you check first? — Whether the topic actually has enough partitions to support more consumers — if partitions are already fully assigned, added instances sit idle and lag won't improve.

### Partition Scaling

Partition scaling refers to increasing the number of partitions for an existing topic (`kafka-topics.sh --alter --partitions N`) to raise the ceiling on consumer parallelism and broker-level write throughput. It's a one-directional operation — Kafka does not support reducing partition count — and it has a critical side effect: existing keyed messages may now hash to a *different* partition than before, breaking per-key ordering guarantees for any key whose target partition changes.

Interviewers dig into this to see if candidates understand that partition scaling isn't "free" — it's a trade-off between raw scalability and ordering guarantees, and it should be planned upfront (over-provisioning partitions moderately at topic creation) rather than reactively increased on a live, ordering-sensitive topic.

**Real-life scenario:** A topic originally created with 6 partitions is scaled to 24 to handle 4x growth, but the team first confirms no downstream consumer logic depends on strict cross-message ordering, since existing keys may now map to new partitions.

**Advantages**
- Increases achievable consumer parallelism and broker throughput.

**Disadvantages**
- Cannot be undone (partitions can only increase, never decrease).
- Can silently break per-key ordering guarantees for existing data.

**Interview Questions**
- Why can you not decrease the number of partitions on a Kafka topic? — Removing a partition would require deciding what happens to its existing, already-ordered data and how it maps to remaining partitions, which Kafka doesn't support doing safely; it's a one-directional operation.
- What ordering risk does increasing partition count introduce for existing keyed messages? — The key-to-partition hash mapping can change for some keys once the partition count changes, so new messages for a previously-seen key may land in a different partition than that key's historical messages, breaking strict ordering across old and new data.
- How would you plan partition count upfront to avoid needing to scale later? — Estimate target throughput and maximum expected consumer parallelism ahead of time and size partitions with headroom, since increasing later risks breaking per-key ordering guarantees on live data.

### Broker Scaling

Broker scaling means adding more broker nodes to a Kafka cluster to increase overall storage capacity, throughput, and fault tolerance headroom. Adding brokers alone doesn't automatically rebalance existing topic-partition replicas onto the new nodes — you need to trigger partition reassignment (via `kafka-reassign-partitions.sh` or a tool like Cruise Control) so existing load actually spreads onto the new hardware.

Interviewers ask about this to gauge operational maturity: simply running `kafka-server-start` on a new node doesn't help until data/leadership is rebalanced onto it, and reassignment itself consumes network/disk I/O that must be throttled to avoid impacting live traffic.

**Real-life scenario:** After adding 3 new brokers to a 6-node cluster, an SRE runs a partition reassignment plan with a throttled bandwidth limit so historical partition data migrates onto the new brokers gradually, without disrupting live producer/consumer traffic.

**Interview Questions**
- Why doesn't simply adding a new broker to a cluster automatically improve throughput? — Existing partitions/leadership stay on the original brokers until a partition reassignment explicitly moves some of them, so a new broker starts out idle with no data or traffic.
- What tool would you use to rebalance existing partitions onto newly added brokers? — `kafka-reassign-partitions.sh` (or a higher-level tool like Cruise Control) to generate and execute a reassignment plan.
- How would you avoid a partition reassignment saturating your network during business hours? — Throttle the reassignment's bandwidth (e.g. via the `--throttle` option) and/or schedule it during low-traffic windows so it doesn't compete with live producer/consumer traffic.

