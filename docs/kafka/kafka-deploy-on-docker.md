# Apache Kafka Cluster with Docker Compose (KRaft Mode)

## Introduction

Apache Kafka is the standard for real-time data pipelines and streaming applications. This guide walks you through setting up a Kafka cluster using Docker Compose in KRaft mode (no Zookeeper required).

---

## Prerequisites

- **Docker & Docker Compose** (tested with Docker 27.0.3)
- **Kafka basics** (Kafka 3.8+)

---

## Architecture Overview

- **3 Kafka brokers** (KRaft mode)
- **Kafka UI** for management
- **Docker network** for communication
- **Persistent volumes** for data

KRaft mode replaces Zookeeper with a built-in consensus mechanism, simplifying the architecture.

---

## Step 1: Project Setup

```bash
mkdir kafka-cluster
cd kafka-cluster
mkdir -p kafka1/data kafka2/data kafka3/data
```

---

## Step 2: Docker Compose Configuration

Create `docker-compose.yml`:

```yaml
version: '3.8'

networks:
    kafka-net:
        driver: bridge

services:
    kafka1:
        image: confluentinc/cp-kafka:7.8.0
        hostname: kafka1
        container_name: kafka1
        ports:
            - "9092:9092"
            - "9093:9093"
        environment:
            KAFKA_NODE_ID: 1
            KAFKA_BROKER_ID: 1
            KAFKA_PROCESS_ROLES: 'broker,controller'
            KAFKA_CONTROLLER_QUORUM_VOTERS: '1@kafka1:9093,2@kafka2:9093,3@kafka3:9093'
            KAFKA_LISTENERS: 'PLAINTEXT://kafka1:9092,CONTROLLER://kafka1:9093'
            KAFKA_ADVERTISED_LISTENERS: 'PLAINTEXT://kafka1:9092'
            KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: 'CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT'
            KAFKA_CONTROLLER_LISTENER_NAMES: 'CONTROLLER'
            KAFKA_INTER_BROKER_LISTENER_NAME: 'PLAINTEXT'
            CLUSTER_ID: 'EmptNWtoR4GGWx-BH6nGLQ'
            KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
            KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
            KAFKA_DEFAULT_REPLICATION_FACTOR: 3
            KAFKA_MIN_INSYNC_REPLICAS: 2
        volumes:
            - ./kafka1/data:/var/lib/kafka/data
        networks:
            - kafka-net

    kafka2:
        image: confluentinc/cp-kafka:7.8.0
        hostname: kafka2
        container_name: kafka2
        ports:
            - "9094:9092"
            - "9095:9093"
        environment:
            KAFKA_NODE_ID: 2
            KAFKA_BROKER_ID: 2
            KAFKA_PROCESS_ROLES: 'broker,controller'
            KAFKA_CONTROLLER_QUORUM_VOTERS: '1@kafka1:9093,2@kafka2:9093,3@kafka3:9093'
            KAFKA_LISTENERS: 'PLAINTEXT://kafka2:9092,CONTROLLER://kafka2:9093'
            KAFKA_ADVERTISED_LISTENERS: 'PLAINTEXT://kafka2:9092'
            KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: 'CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT'
            KAFKA_CONTROLLER_LISTENER_NAMES: 'CONTROLLER'
            KAFKA_INTER_BROKER_LISTENER_NAME: 'PLAINTEXT'
            CLUSTER_ID: 'EmptNWtoR4GGWx-BH6nGLQ'
            KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
            KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
            KAFKA_DEFAULT_REPLICATION_FACTOR: 3
            KAFKA_MIN_INSYNC_REPLICAS: 2
        volumes:
            - ./kafka2/data:/var/lib/kafka/data
        networks:
            - kafka-net

    kafka3:
        image: confluentinc/cp-kafka:7.8.0
        hostname: kafka3
        container_name: kafka3
        ports:
            - "9096:9092"
            - "9097:9093"
        environment:
            KAFKA_NODE_ID: 3
            KAFKA_BROKER_ID: 3
            KAFKA_PROCESS_ROLES: 'broker,controller'
            KAFKA_CONTROLLER_QUORUM_VOTERS: '1@kafka1:9093,2@kafka2:9093,3@kafka3:9093'
            KAFKA_LISTENERS: 'PLAINTEXT://kafka3:9092,CONTROLLER://kafka3:9093'
            KAFKA_ADVERTISED_LISTENERS: 'PLAINTEXT://kafka3:9092'
            KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: 'CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT'
            KAFKA_CONTROLLER_LISTENER_NAMES: 'CONTROLLER'
            KAFKA_INTER_BROKER_LISTENER_NAME: 'PLAINTEXT'
            CLUSTER_ID: 'EmptNWtoR4GGWx-BH6nGLQ'
            KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
            KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
            KAFKA_DEFAULT_REPLICATION_FACTOR: 3
            KAFKA_MIN_INSYNC_REPLICAS: 2
        volumes:
            - ./kafka3/data:/var/lib/kafka/data
        networks:
            - kafka-net

    kafka-ui:
        image: provectuslabs/kafka-ui:latest
        container_name: kafka-cluster-ui
        ports:
            - "8080:8080"
        environment:
            KAFKA_CLUSTERS_0_NAME: local
            KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka1:9092,kafka2:9092,kafka3:9092
        depends_on:
            - kafka1
            - kafka2
            - kafka3
        networks:
            - kafka-net
```

---

## Step 3: Configuration Breakdown

### Network

```yaml
networks:
    kafka-net:
        driver: bridge
```
Creates an isolated network for secure container communication.

### Brokers

- **KRaft mode:**  
    `KAFKA_PROCESS_ROLES: 'broker,controller'`
- **Listeners:**  
    `KAFKA_LISTENERS` and `KAFKA_ADVERTISED_LISTENERS` define how brokers and clients connect.
- **Replication:**  
    - `KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR`: Replication for `__consumer_offsets` topic.
    - `KAFKA_DEFAULT_REPLICATION_FACTOR`: Default partition replication.
    - `KAFKA_MIN_INSYNC_REPLICAS`: Minimum replicas for write acknowledgment.

---

## Step 4: Launch the Cluster

```bash
docker compose -f docker-compose.yml up -d
```

Check containers:

```bash
docker compose ps
```

---

## Step 5: Test the Cluster

Create a topic:

```bash
docker exec -it kafka1 kafka-topics \
    --create \
    --topic test-topic \
    --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092 \
    --replication-factor 3 \
    --partitions 3
```

List topics:

```bash
docker exec -it kafka1 kafka-topics \
    --list \
    --bootstrap-server kafka1:9092
```

Describe topic:

```bash
docker exec -it kafka1 kafka-topics \
    --describe \
    --topic test-topic \
    --bootstrap-server kafka1:9092
```


### Create a Producer

You can produce messages to your topic using the Kafka CLI:

```bash
docker exec -it kafka1 kafka-console-producer \
    --broker-list kafka1:9092 \
    --topic test-topic
```

Type your messages and press Enter to send them.

---

### Create a Consumer from Offset 0

Consume messages from the beginning of the topic:

```bash
docker exec -it kafka1 kafka-console-consumer \
    --bootstrap-server kafka1:9092 \
    --topic test-topic \
    --from-beginning
```

This will display all messages from offset 0.



### Produce Messages with Keys and Consumer Groups

You can produce messages with a key using the Kafka CLI:

```bash
docker exec -it kafka1 kafka-console-producer \
    --broker-list kafka1:9092 \
    --topic test-topic \
    --property "parse.key=true" \
    --property "key.separator=:"
```

Type messages in the format `key1:value1`, `key2:value2`, etc.

---

### Create Two Consumers in the Same Consumer Group

Start two consumers with the same group ID to enable partition assignment and load balancing:

**Consumer 1:**

```bash
docker exec -it kafka1 kafka-console-consumer \
    --bootstrap-server kafka1:9092 \
    --topic test-topic \
    --group my-consumer-group
```

**Consumer 2:**

```bash
docker exec -it kafka2 kafka-console-consumer \
    --bootstrap-server kafka2:9092 \
    --topic test-topic \
    --group my-consumer-group
```

Both consumers will share the workload and receive messages according to partition assignment within the group.


---

## Step 6: Kafka UI

Access [http://localhost:8080](http://localhost:8080) for:

- Broker health
- Topic management
- Consumer groups
- Message browsing
- Metrics

---

## Production Considerations

### Security

- Enable SSL/TLS
- Use SASL authentication
- Set ACLs
- Secure Kafka UI

### Performance

- Tune replica fetch/batch sizes
- Set retention policies
- Adjust JVM heap

### Monitoring

- Prometheus metrics
- Grafana dashboards
- Alerts/log aggregation

---

## Conclusion

You now have a production-ready Kafka cluster in Docker with:

- Three-node redundancy
- KRaft consensus (no Zookeeper)
- Web UI
- Persistent storage
- Network isolation

This setup is a solid foundation for scalable streaming applications.

---

## Resources

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Confluent Docker Images](https://hub.docker.com/r/confluentinc/cp-kafka)
- [Kafka UI GitHub](https://github.com/provectus/kafka-ui)

## FAQ

### How can I define my `cluster_id`?

Kafka provides a helper command to generate a random cluster ID:

```bash
kafka-storage.sh random-uuid
```

You can use the output of this command as your `CLUSTER_ID` in the Docker Compose configuration.

---

Thank you, it's very helpful for me.
