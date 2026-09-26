# Redis Best Practices

## Theory

### Key Naming Strategy

A consistent key naming convention is foundational to a maintainable Redis deployment: it makes debugging easier, enables safe `SCAN`-based pattern matching, avoids accidental collisions between unrelated features, and documents the data model implicitly through the keyspace itself. The de facto standard convention is colon-delimited segments ordered from general to specific: `{object-type}:{id}:{sub-resource}`, e.g., `user:1001:profile`, `order:9001:items`, `rate-limit:api-key-abc:endpoint-x`.

```bash
# Good: consistent, hierarchical, scannable
user:1001
user:1001:sessions
order:9001:items
cache:product:77

# Avoid: inconsistent separators, ambiguous meaning, no namespace
User_1001
1001-order
tempdata123
```

Namespacing by environment or application (e.g., prefixing with `prod:` or a service name when multiple applications share a Redis instance/cluster) further reduces the risk of cross-application key collisions, and makes it possible to selectively flush or migrate a subset of keys using pattern-based tooling.

### TTL Strategy

Setting an appropriate TTL (time-to-live) on keys is one of the most impactful and most frequently overlooked Redis best practices — keys without a TTL live forever unless explicitly deleted, and in a cache-style workload this leads to unbounded memory growth and eventual reliance on eviction policies to reclaim space, often evicting keys that are still useful while stale, forgotten keys linger.

Every key should have a deliberate TTL decision: session keys get a TTL matching the desired session timeout (refreshed on activity for sliding expiration); cache entries get a TTL balancing data freshness against cache hit ratio; rate-limiter window keys get a TTL matching the window length; and genuinely permanent data (if Redis is used as a system of record, not just a cache) is explicitly exempted with a documented reason, rather than "just never expiring by accident."

```bash
# Set a value with an expiration in one atomic command
SET cache:product:77 "{...}" EX 600

# Set TTL on an existing key
EXPIRE session:a1b2c3 1800

# Check remaining TTL (-1 = no TTL set, -2 = key does not exist)
TTL cache:product:77

# Remove a TTL, making a key persistent (use deliberately, rarely by accident)
PERSIST cache:product:77
```

### Memory Optimization

Since Redis holds the entire working dataset in RAM, memory efficiency directly affects both cost and headroom before hitting eviction/OOM conditions. The most effective optimizations are structural: using compact encodings for small collections (Redis automatically uses `listpack`/`ziplist`-style compact encodings for small hashes, lists, and sorted sets below configurable size thresholds, falling back to full hash tables/skiplists only once they grow large), avoiding storing redundant or derivable data, and using shorter key/field names when key volume is extremely high (the per-key overhead becomes significant at hundreds of millions of keys).

```bash
# Encoding thresholds (small collections use compact memory layout automatically)
redis-cli CONFIG GET hash-max-listpack-entries
redis-cli CONFIG GET hash-max-listpack-value
redis-cli CONFIG GET set-max-listpack-entries
redis-cli CONFIG GET zset-max-listpack-entries

# Check current encoding of a key
redis-cli OBJECT ENCODING user:1001
```

Other impactful techniques: preferring `HASH` for many small related fields instead of many individual `STRING` keys (each standalone key has fixed per-key overhead beyond just the value bytes), using `HyperLogLog`/bitmaps for approximate/boolean data instead of full sets, enabling compression at the serialization layer for large string values, and periodically auditing with `redis-cli --bigkeys`/`MEMORY USAGE` to find and address outsized keys.

### Choosing Appropriate Data Types

This best practice is the operational counterpart to the "Choosing the Right Data Type" modeling topic covered earlier: beyond correctness, the data type choice has direct, measurable effects on memory footprint and command complexity in production. A common anti-pattern is using a `STRING` holding a serialized JSON object for data that's frequently partially updated — every field change requires deserializing, mutating, and rewriting the entire blob, and is not atomic across the read-modify-write unless wrapped in a transaction or Lua script, whereas a `HASH` supports atomic partial field updates natively (`HSET`, `HINCRBY`) with lower overhead.

The practical guideline: default to `HASH` for structured objects with independently-updated fields, `SET`/`ZSET` for membership/ranking rather than scanning `LIST`s, and reserve `STRING` for genuinely atomic, whole-value data (simple counters, cached blobs that are always read/written in full, tokens). Revisit the choice whenever an access pattern changes — a data type that was appropriate at low scale can become a bottleneck once collection sizes or update frequency grow.

### Avoiding Large Keys

A single Redis key backing a very large collection (a `HASH` with millions of fields, a `LIST`/`SET`/`ZSET` with millions of members, or a `STRING` holding a multi-megabyte blob) creates several operational problems: commands that touch the whole collection (`HGETALL`, `SMEMBERS`, `LRANGE 0 -1`) become O(N) and can block the single-threaded event loop for a noticeable duration; replication and persistence (RDB/AOF) must serialize the entire key as one unit, causing latency spikes; and rebalancing in a clustered deployment (resharding) is harder since a single key cannot be split across slots.

```bash
# Detect large keys proactively (non-blocking sampling scan)
redis-cli --bigkeys

# Check the memory footprint of a specific suspect key
redis-cli MEMORY USAGE mykey SAMPLES 0
```

The fix is almost always to shard the large collection across multiple keys — for example, splitting a giant hash `user:1001:events` into time-bucketed hashes (`user:1001:events:2026-08`), or hashing a member ID into one of N sub-keys (`big_set:{hash(member) % 16}`) — trading a small amount of application-side complexity for bounded per-key size and safer operational characteristics.

### Avoiding Hot Keys

A hot key is a single key that receives a disproportionate share of traffic relative to the rest of the keyspace — a viral social media post's like-counter, a globally shared configuration flag, or a celebrity's profile in a social app. Because a single key in non-clustered Redis is served by a single node (and even in Redis Cluster, a single key always lives on exactly one shard, never load-balanced across shards), a sufficiently hot key can saturate that one node's CPU/network capacity regardless of how many replicas or shards exist elsewhere in the topology.

Mitigations include: adding a local (in-process) cache layer in front of Redis for extremely hot, slowly-changing data (accepting brief staleness); sharding a hot counter into N sub-keys that are incremented round-robin or randomly and summed on read (trading read simplicity for write scalability); and using read replicas to spread hot-key *read* traffic (though this does not help with hot-key *write* traffic, which always goes to the primary/owning shard).

```bash
# Sharded hot counter pattern: spread writes across N sub-keys
INCR hot_counter:{shard_0}
INCR hot_counter:{shard_1}
# ... reader sums all shards
```

### Pipelining

Pipelining batches multiple commands into a single network round trip: instead of sending a command, waiting for its reply, then sending the next command (paying full network latency per command), the client sends all commands back-to-back and reads all responses afterward, amortizing network latency across the whole batch. This is purely a client-side optimization — Redis still executes each command individually and sequentially — but it dramatically improves throughput for workloads issuing many independent commands, especially over higher-latency networks (cross-AZ or cross-region).

```bash
# redis-cli pipe mode reads commands from stdin and pipelines them
(echo -e "SET a 1\nSET b 2\nSET c 3\nGET a") | redis-cli --pipe
```

```java
// Spring Data Redis: pipelining via RedisTemplate.executePipelined
List<Object> results = redisTemplate.executePipelined((RedisCallback<Object>) connection -> {
    for (int i = 0; i < 1000; i++) {
        connection.stringCommands().set(("key:" + i).getBytes(), "value".getBytes());
    }
    return null; // return value is ignored in pipelined callback; results collected separately
});
```

Pipelining should not be confused with transactions (`MULTI`/`EXEC`) — pipelining is purely about batching network I/O, while transactions additionally guarantee the batched commands execute atomically as a unit without other clients' commands interleaving (Redis actually pipelines the commands inside a transaction internally too, but the atomicity guarantee is the distinguishing feature).

### Batching

Batching, in the Redis context, generally refers to grouping logically related operations into a single command wherever the API supports it natively, rather than issuing N separate commands (with or without pipelining). Many Redis commands have native multi-key/multi-value variants: `MSET`/`MGET` for multiple string key-value pairs in one round trip, `HSET` accepting multiple field-value pairs at once, `SADD`/`ZADD` accepting multiple members in a single call, and `DEL` accepting multiple keys.

```bash
# Batch multiple SETs into one command instead of N round trips
MSET user:1:name "Alice" user:2:name "Bob" user:3:name "Carol"

# Batch multiple GETs
MGET user:1:name user:2:name user:3:name

# Batch multiple hash field writes
HSET user:1001 name "Alice" email "alice@example.com" plan "pro"
```

Native batching commands are preferable to pipelining N single-key commands when available, since they involve a single command dispatch/parsing overhead on the server rather than N, though for very large batches, chunking (e.g., 500-1000 keys per `MSET` call) is still advisable to avoid an overly large single command payload and to keep the server responsive to other clients between chunks.

### Monitoring and Alerting

Best-practice monitoring combines the metrics and tools already covered (`INFO`, Slow Log, Latency Monitor, Prometheus/Grafana) into a proactive alerting strategy rather than only reactive incident investigation. The goal is to catch degradation trends (memory approaching `maxmemory`, replication lag growing, hit ratio declining) before they cause a user-facing incident, and to alert on symptoms that reliably precede outages based on prior incident history.

Recommended baseline alerts: memory usage above 80-90% of `maxmemory`; non-zero `evicted_keys` rate on a cache expected to fully fit in memory; replication offset lag beyond an acceptable threshold (seconds, tuned to application tolerance); `rejected_connections` greater than zero; Slow Log entries exceeding a rate threshold; and instance-down/health-check failures with fast paging for primary nodes. Dashboards should surface hit/miss ratio, command throughput, p50/p99 latency (via Latency Monitor or client-side instrumentation), memory usage trend over time, and connected clients count.

```bash
# Quick manual health check combining several best-practice signals
redis-cli INFO memory | grep -E "used_memory_human|maxmemory_human|mem_fragmentation_ratio"
redis-cli INFO stats | grep -E "evicted_keys|expired_keys|rejected_connections"
redis-cli INFO replication | grep -E "role|master_repl_offset|connected_slaves"
```

### Interview Questions

1. What key naming conventions do you follow in Redis, and why do they matter at scale? — Use colon-delimited, general-to-specific segments (`{object-type}:{id}:{sub-resource}`), optionally namespaced by environment or service; consistent naming makes `SCAN`-based pattern matching reliable, avoids accidental cross-feature key collisions, and effectively documents the data model through the keyspace itself as the system grows.
2. Why should almost every cache key have a TTL, and what happens if TTLs are forgotten? — A deliberate TTL keeps memory usage bounded and cache content fresh; without one, keys live forever until explicitly deleted, leading to unbounded memory growth that eventually forces reliance on eviction policies, which can evict still-useful keys while genuinely stale, forgotten keys linger indefinitely.
3. What Redis-internal encodings help optimize memory for small collections, and how do you inspect a key's current encoding? — Redis automatically uses compact `listpack`/`ziplist`-style encodings for small hashes, lists, sets, and sorted sets below configurable size thresholds (`hash-max-listpack-entries`, `zset-max-listpack-entries`, etc.), falling back to full hash tables/skiplists only once a collection exceeds them; the current encoding of a key can be inspected with `OBJECT ENCODING <key>`.
4. What is a "hot key," why can't sharding/clustering alone fix it, and how would you mitigate one? — A hot key receives disproportionate traffic (e.g., a viral post's counter), and since any single key always lives on exactly one node/shard regardless of cluster size, that one node's CPU/network capacity bounds the key's throughput no matter how many other shards exist; mitigations include a local in-process cache for hot reads, sharding the counter into N sub-keys summed on read, and offloading hot-key reads to replicas.
5. What problems does a very large single key (e.g., a hash with millions of fields) cause, and how would you fix it? — Commands that touch the whole key (`HGETALL`, `SMEMBERS`, `LRANGE 0 -1`) become O(N) and can block the single-threaded event loop noticeably, replication/persistence must serialize the entire key as one unit causing latency spikes, and a single key cannot be split across Cluster slots during resharding; the fix is to shard the collection across multiple keys, such as time-bucketing or hashing a member ID into one of N sub-keys.
6. What is pipelining, how does it improve performance, and how is it different from a Redis transaction? — Pipelining batches multiple commands into a single network round trip, sending them all before reading any replies, which amortizes network latency across the batch and dramatically improves throughput; unlike a transaction (`MULTI`/`EXEC`), pipelining is purely a client-side I/O optimization and provides no atomicity guarantee against interleaving from other clients.
7. What native Redis commands support batching multiple operations in a single round trip? — `MSET`/`MGET` batch multiple string key-value pairs, `HSET` accepts multiple field-value pairs in one call, `SADD`/`ZADD` accept multiple members at once, and `DEL` accepts multiple keys, all of which involve a single command dispatch/parsing overhead on the server rather than N separate ones.
8. What memory-related metrics and thresholds would you set alerts on for a production Redis cluster? — Alert when `used_memory` exceeds roughly 80-90% of `maxmemory`, when `evicted_keys` shows a nonzero rate on a cache expected to fully fit in memory, and when `mem_fragmentation_ratio` climbs well above 1.5, since all three signal impending or active memory pressure that can lead to evictions, OOM write rejections, or degraded allocator performance.
9. How would you detect and remediate memory fragmentation in Redis? — Detect it via `mem_fragmentation_ratio` in `INFO memory` (the ratio of OS-allocated RSS to Redis-reported used memory); remediate by running `MEMORY PURGE` to return unused memory to the OS (jemalloc only), enabling `activedefrag` for online incremental defragmentation, or restarting the instance during a maintenance window if fragmentation is severe and defrag settings aren't sufficient.
10. What's the difference between `EXPIRE`, `PERSIST`, and `TTL`, and how do you use them together for sliding-window session expiration? — `EXPIRE` sets or refreshes a key's time-to-live, `TTL` reports the remaining seconds (-1 for no TTL, -2 if the key doesn't exist), and `PERSIST` removes an existing TTL, making the key permanent; for sliding-window session expiration, you call `EXPIRE` again on every active request to reset the countdown, so an idle session naturally expires while an active one never does.
11. How would you decide whether to use `HASH` vs `STRING` for a given piece of structured data from a best-practices standpoint? — Default to `HASH` whenever fields are updated independently, since it supports atomic partial updates (`HSET`, `HINCRBY`) with lower per-update overhead; reserve `STRING` for genuinely atomic, whole-value data such as simple counters, tokens, or blobs that are always read and written in full together.
12. Why is `redis-cli --bigkeys` preferred over `KEYS *` or repeated `MEMORY USAGE` calls for auditing a large keyspace? — `--bigkeys` uses non-blocking `SCAN` cursors to sample the keyspace incrementally, avoiding the event-loop-blocking behavior of `KEYS *` on a large dataset, and it aggregates per-type size statistics in one pass, whereas issuing `MEMORY USAGE` per key doesn't scale to millions of keys and adds proportional load to the server.

