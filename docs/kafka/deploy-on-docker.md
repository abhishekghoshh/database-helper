# Kafka Cluster Docker Compose Documentation

This document provides a comprehensive explanation of the Kafka cluster deployment using Docker Compose. The setup includes a 3-node Kafka cluster running in KRaft mode (without Zookeeper), along with supporting services for monitoring, management, and data integration.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Networks](#networks)
- [Volumes](#volumes)
- [Services](#services)
  - [init-kafka](#init-kafka)
  - [kafka1, kafka2, kafka3](#kafka1-kafka2-kafka3)
  - [busybox](#busybox)
  - [kafka-init-topics](#kafka-init-topics)
  - [kafka-ui](#kafka-ui)
  - [schema-registry](#schema-registry)
  - [kafka-connect](#kafka-connect)
  - [prometheus](#prometheus)
  - [filebrowser](#filebrowser)
- [Testing the Cluster](#testing-the-cluster)

---

## Architecture Overview

This setup creates a production-ready Kafka cluster with the following components:
- **3-node Kafka cluster** in KRaft mode (Kafka without Zookeeper)
- **Schema Registry** for managing Avro/JSON schemas
- **Kafka Connect** for data integration
- **Kafka UI** for cluster management and monitoring
- **Prometheus** for metrics collection
- **FileBrowser** for browsing cluster data and logs

---

## Networks

### kafka-net
```yaml
networks:
  kafka-net:
    driver: bridge
```

**Purpose**: Creates a custom bridge network for all Kafka-related services to communicate with each other.

**Why it's used**: 
- Provides network isolation for the Kafka cluster
- Enables service discovery using container names as hostnames
- Allows containers to communicate using internal DNS resolution

---

## Volumes

### kafka-cluster
```yaml
volumes:
  kafka-cluster:
```

**Purpose**: A named Docker volume that persists Kafka data, logs, and shared files across container restarts.

**Why it's used**:
- Ensures data persistence even if containers are removed
- Shared across all Kafka brokers and utility containers
- Stores topic data, broker logs, and application logs

**Directory Structure**:
```
/mnt/shared/
├── kafka1/
│   ├── data/  (topic partitions and logs)
│   └── logs/  (application logs)
├── kafka2/
│   ├── data/
│   └── logs/
└── kafka3/
    ├── data/
    └── logs/
```

---

## Services

### init-kafka

```yaml
init-kafka:
  image: alpine:latest
  container_name: init-kafka
```

**What it is**: A one-time initialization service that prepares the filesystem structure before Kafka brokers start.

**Image**: `alpine:latest` - Lightweight Linux distribution (only ~5MB)

**Command**:
```bash
sh -c "
  echo 'Creating directory structure...';
  mkdir -p /mnt/shared/kafka1/data /mnt/shared/kafka1/logs;
  mkdir -p /mnt/shared/kafka2/data /mnt/shared/kafka2/logs;
  mkdir -p /mnt/shared/kafka3/data /mnt/shared/kafka3/logs;
  echo 'Setting permissions...';
  chmod -R 777 /mnt/shared;
  echo 'Initialization complete.';
"
```

**Purpose**:
- Creates required directory structure for each Kafka broker
- Sets proper permissions (777) to avoid permission issues
- Runs once before Kafka brokers start (via `depends_on`)

**Volumes**:
- `kafka-cluster:/mnt/shared` - Mounts the shared volume to create directories

**Network**: `kafka-net`

**Why it's needed**: Kafka brokers need pre-existing directories with proper permissions to store data and logs. This service ensures these directories exist before brokers attempt to write to them.

---

### kafka1, kafka2, kafka3

**What they are**: Three Kafka broker nodes forming a high-availability cluster using KRaft mode (Kafka's built-in consensus protocol, replacing Zookeeper).

**Image**: `confluentinc/cp-kafka:7.8.0` - Confluent's Kafka distribution version 7.8.0

#### kafka1 Configuration

**Ports**:
- `9092:9092` - Client connections (producers/consumers connect here)
- `9093:9093` - Controller communication (KRaft consensus protocol)
- `9997:9997` - JMX metrics port for monitoring

**Environment Variables**:

##### Node Identity
- **KAFKA_NODE_ID**: `1`
  - Unique identifier for this node in the KRaft cluster
  - Must be unique across all brokers
  
- **KAFKA_BROKER_ID**: `1`
  - Legacy broker ID (kept for compatibility)
  - Should match NODE_ID

- **CLUSTER_ID**: `EmptNWtoR4GGWx-BH6nGLQ`
  - Unique cluster identifier
  - **Critical**: Must be identical across all brokers in the cluster
  - Generated once and reused for cluster formation

##### Process Roles
- **KAFKA_PROCESS_ROLES**: `broker,controller`
  - Defines what roles this node plays
  - `broker`: Handles client requests and stores data
  - `controller`: Participates in cluster metadata management (KRaft mode)
  - Combined mode means each node is both a broker and controller

##### KRaft Quorum Configuration
- **KAFKA_CONTROLLER_QUORUM_VOTERS**: `1@kafka1:9093,2@kafka2:9093,3@kafka3:9093`
  - Lists all controller nodes in the cluster
  - Format: `{node-id}@{hostname}:{controller-port}`
  - Used for leader election and metadata replication
  - All 3 nodes participate in the quorum for fault tolerance

##### Listeners Configuration
- **KAFKA_LISTENERS**: `PLAINTEXT://kafka1:9092,CONTROLLER://kafka1:9093`
  - Defines the addresses Kafka binds to
  - `PLAINTEXT://kafka1:9092`: Listens for client connections
  - `CONTROLLER://kafka1:9093`: Listens for controller-to-controller communication

- **KAFKA_ADVERTISED_LISTENERS**: `PLAINTEXT://kafka1:9092`
  - The address Kafka advertises to clients
  - Clients use this to connect to the broker
  - Only advertises the client listener (not the controller listener)

- **KAFKA_LISTENER_SECURITY_PROTOCOL_MAP**: `CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT`
  - Maps listener names to security protocols
  - `CONTROLLER:PLAINTEXT`: Controller communication uses plaintext (no encryption)
  - `PLAINTEXT:PLAINTEXT`: Client communication uses plaintext

- **KAFKA_CONTROLLER_LISTENER_NAMES**: `CONTROLLER`
  - Specifies which listener is used for controller communication
  - Must match one of the listener names in KAFKA_LISTENERS

- **KAFKA_INTER_BROKER_LISTENER_NAME**: `PLAINTEXT`
  - Specifies which listener brokers use to communicate with each other
  - Used for replication and cluster coordination

##### Replication Configuration
- **KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR**: `3`
  - Replication factor for the `__consumer_offsets` topic
  - Set to 3 for high availability (one copy on each broker)
  - This topic stores consumer group offsets

- **KAFKA_DEFAULT_REPLICATION_FACTOR**: `3`
  - Default replication factor for new topics (if not specified)
  - Ensures all data is replicated across all 3 brokers

- **KAFKA_MIN_INSYNC_REPLICAS**: `2`
  - Minimum number of replicas that must acknowledge a write
  - Set to 2 for a balance between availability and durability
  - With 3 replicas, can tolerate 1 broker failure while maintaining writes

##### Consumer Group Configuration
- **KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS**: `0`
  - Delay before first consumer group rebalance
  - Set to 0 for development (no delay)
  - In production, typically set higher (e.g., 3000ms) to allow all consumers to join

##### Transaction Configuration
- **KAFKA_TRANSACTION_STATE_LOG_MIN_ISR**: `1`
  - Minimum in-sync replicas for transaction log
  - Set to 1 for development (allows transactions even with broker failures)

- **KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR**: `1`
  - Replication factor for transaction state log
  - Set to 1 for development (typically 3 in production)

##### JMX Monitoring Configuration
- **KAFKA_JMX_PORT**: `9997`
  - Port for JMX (Java Management Extensions) metrics
  - Used by monitoring tools like Prometheus to scrape metrics

- **KAFKA_JMX_OPTS**: Complex JVM options string
  ```
  -Dcom.sun.management.jmxremote 
  -Dcom.sun.management.jmxremote.authenticate=false 
  -Dcom.sun.management.jmxremote.ssl=false 
  -Djava.rmi.server.hostname=kafka1 
  -Dcom.sun.management.jmxremote.rmi.port=9997
  ```
  - Enables JMX remote monitoring
  - Disables authentication and SSL (for development only)
  - Sets RMI hostname to `kafka1` for proper connectivity
  - Binds RMI to port 9997

##### Storage Configuration
- **KAFKA_LOG_DIRS**: `/mnt/shared/kafka1/data`
  - Directory where Kafka stores topic data (log segments)
  - Each partition is stored as a subdirectory
  - Critical for data persistence

- **LOG_DIR**: `/mnt/shared/kafka1/logs`
  - Directory for application logs (server.log, gc.log, etc.)
  - Separate from data storage for better organization

**Volumes**:
- `kafka-cluster:/mnt/shared` - Mounts shared volume for data and logs

**Networks**: `kafka-net`

**Dependencies**: `init-kafka` - Waits for directory initialization

#### kafka2 Configuration

Identical to kafka1 with the following differences:

**Ports**:
- `9094:9092` - Client connections (mapped to host port 9094)
- `9095:9093` - Controller communication (mapped to host port 9095)

**Node-specific Environment Variables**:
- `KAFKA_NODE_ID: 2`
- `KAFKA_BROKER_ID: 2`
- `KAFKA_LISTENERS: PLAINTEXT://kafka2:9092,CONTROLLER://kafka2:9093`
- `KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka2:9092`
- `KAFKA_JMX_OPTS`: Uses `kafka2` as hostname
- `KAFKA_LOG_DIRS: /mnt/shared/kafka2/data`
- `LOG_DIR: /mnt/shared/kafka2/logs`

#### kafka3 Configuration

Identical to kafka1 with the following differences:

**Ports**:
- `9096:9092` - Client connections (mapped to host port 9096)
- `9097:9093` - Controller communication (mapped to host port 9097)

**Node-specific Environment Variables**:
- `KAFKA_NODE_ID: 3`
- `KAFKA_BROKER_ID: 3`
- `KAFKA_LISTENERS: PLAINTEXT://kafka3:9092,CONTROLLER://kafka3:9093`
- `KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka3:9092`
- `KAFKA_JMX_OPTS`: Uses `kafka3` as hostname
- `KAFKA_LOG_DIRS: /mnt/shared/kafka3/data`
- `LOG_DIR: /mnt/shared/kafka3/logs`

**Why 3 brokers?**:
- Provides high availability and fault tolerance
- Allows replication factor of 3
- Can survive 1 broker failure while maintaining data availability
- Enables proper quorum-based leader election in KRaft mode

---

### busybox

```yaml
busybox:
  image: confluentinc/cp-kafka:7.8.0
  container_name: busybox
  hostname: busybox
  command: /scripts/init-script.sh
```

**What it is**: A utility container that runs custom initialization scripts after the Kafka cluster is ready.

**Image**: `confluentinc/cp-kafka:7.8.0` - Uses the same Kafka image to have access to Kafka CLI tools

**Command**: `/scripts/init-script.sh` - Executes a custom shell script

**Environment Variables**:
- **TZ**: `America/New_York`
  - Sets the timezone for the container
  - Useful for consistent timestamp logging

- **KAFKA_BROKER_1**: `kafka1:9092`
- **KAFKA_BROKER_2**: `kafka2:9092`
- **KAFKA_BROKER_3**: `kafka3:9092`
  - Environment variables for easy access to broker addresses
  - Can be used in scripts without hardcoding broker URLs

**Volumes**:
- `kafka-cluster:/mnt/shared` - Access to shared volume
- `./scripts:/scripts` - Mounts local scripts directory into container

**Working Directory**: `/scripts` - Scripts are executed from this directory

**Dependencies**: Depends on all three Kafka brokers being up

**Network**: `kafka-net`

**Why it's used**: 
- Runs custom initialization tasks after cluster is ready
- Can create topics, configure ACLs, or perform health checks
- Provides a container with Kafka tools for debugging

---

### kafka-init-topics

```yaml
kafka-init-topics:
  image: confluentinc/cp-kafka:7.8.0
  container_name: kafka-init-topics
```

**What it is**: An initialization container that creates topics and loads sample data when the cluster starts.

**Image**: `confluentinc/cp-kafka:7.8.0` - Contains Kafka command-line tools

**Volumes**:
- `./data/message.json:/data/message.json` - Mounts sample data file

**Command Breakdown**:
```bash
sh -c 'echo Waiting for Kafka to be ready... && \
       cub kafka-ready -b kafka1:9092 1 30 && \
       kafka-topics --create --topic users --partitions 3 --replication-factor 3 --if-not-exists --bootstrap-server kafka1:9092 && \
       kafka-topics --create --topic messages --partitions 3 --replication-factor 3 --if-not-exists --bootstrap-server kafka1:9092 && \
       kafka-console-producer --bootstrap-server kafka1:9092 --topic users < /data/message.json'
```

**Command Steps**:
1. **Wait for Kafka**: `cub kafka-ready -b kafka1:9092 1 30`
   - `cub` (Confluent Utility Belt) checks if Kafka is ready
   - `-b kafka1:9092`: Bootstrap server to check
   - `1`: Minimum number of brokers required
   - `30`: Timeout in seconds

2. **Create 'users' topic**: 
   ```bash
   kafka-topics --create --topic users --partitions 3 --replication-factor 3 --if-not-exists --bootstrap-server kafka1:9092
   ```
   - Creates a topic named `users`
   - `--partitions 3`: Splits topic into 3 partitions for parallel processing
   - `--replication-factor 3`: Replicates each partition to all 3 brokers
   - `--if-not-exists`: Prevents errors if topic already exists

3. **Create 'messages' topic**: Same as above for `messages` topic

4. **Load sample data**:
   ```bash
   kafka-console-producer --bootstrap-server kafka1:9092 --topic users < /data/message.json
   ```
   - Produces messages from `message.json` to the `users` topic
   - Uses stdin redirection to read from file

**Dependencies**: All three Kafka brokers must be running

**Network**: `kafka-net`

**Why it's used**:
- Automates topic creation on cluster startup
- Pre-loads sample data for testing
- Ensures topics have proper partitioning and replication

---

### kafka-ui

```yaml
kafka-ui:
  image: ghcr.io/kafbat/kafka-ui:latest
  container_name: kafka-ui
```

**What it is**: A modern web-based UI for managing and monitoring Kafka clusters (formerly known as kafka-ui by Provectus).

**Image**: `ghcr.io/kafbat/kafka-ui:latest` - Latest version of Kafbat UI

**Ports**:
- `8080:8080` - Web interface accessible at http://localhost:8080

**Environment Variables**:

##### Cluster Configuration
- **KAFKA_CLUSTERS_0_NAME**: `local`
  - Display name for the cluster in the UI
  - The `0` indicates this is the first (and only) cluster

- **KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS**: `kafka1:9092,kafka2:9092,kafka3:9092`
  - Comma-separated list of broker addresses
  - UI connects to these brokers to retrieve cluster information

##### Metrics Configuration
- **KAFKA_CLUSTERS_0_METRICS_PORT**: `9997`
  - JMX port to scrape metrics from brokers
  - Enables performance monitoring in the UI

- **KAFKA_CLUSTERS_0_METRICS_STORE_PROMETHEUS_URL**: `http://prometheus:9090`
  - URL of Prometheus server for historical metrics
  - Allows viewing metrics trends over time

- **KAFKA_CLUSTERS_0_METRICS_STORE_PROMETHEUS_REMOTEWRITE**: `true`
  - Enables remote write to Prometheus
  - Pushes metrics to Prometheus for storage

- **KAFKA_CLUSTERS_0_METRICS_STORE_KAFKA_TOPIC**: `kafka_metrics`
  - Kafka topic for storing metrics data
  - Allows metrics to be persisted in Kafka itself

##### Kafka Connect Integration
- **KAFKA_CLUSTERS_0_KAFKACONNECT_0_ADDRESS**: `http://kafka-connect:8083`
  - URL of Kafka Connect cluster
  - Enables managing connectors from the UI

- **KAFKA_CLUSTERS_0_KAFKACONNECT_0_NAME**: `first`
  - Display name for this Connect cluster

##### Schema Registry Integration
- **KAFKA_CLUSTERS_0_SCHEMAREGISTRY**: `http://schema-registry:8085`
  - URL of Schema Registry service
  - Allows viewing and managing schemas from the UI

##### UI Features
- **DYNAMIC_CONFIG_ENABLED**: `true`
  - Allows modifying cluster configuration through the UI
  - Enables dynamic updates without restarting

**Dependencies**: 
- Kafka brokers (kafka1, kafka2, kafka3)
- schema-registry
- kafka-connect

**Network**: `kafka-net`

**Why it's used**:
- Provides a user-friendly interface for cluster management
- Monitors topics, partitions, consumer groups, and brokers
- Manages schemas and connectors
- Visualizes metrics and cluster health
- Allows producing/consuming messages for testing

---

### schema-registry

```yaml
schema-registry:
  image: confluentinc/cp-schema-registry:7.8.0
  container_name: schema-registry
  hostname: schema-registry
```

**What it is**: A centralized service for managing and enforcing schemas for Kafka messages (Avro, JSON Schema, Protobuf).

**Image**: `confluentinc/cp-schema-registry:7.8.0` - Confluent's Schema Registry

**Ports**:
- `8081:8081` - Primary REST API endpoint
- `8085:8085` - Secondary listener (used by Kafka UI)

**Environment Variables**:

##### Basic Configuration
- **SCHEMA_REGISTRY_HOST_NAME**: `schema-registry`
  - Hostname for this Schema Registry instance
  - Used for service identification

- **SCHEMA_REGISTRY_LISTENERS**: `http://schema-registry:8081,http://schema-registry:8085`
  - Comma-separated list of HTTP endpoints to listen on
  - Multiple listeners allow different services to connect on different ports

##### Kafka Connection
- **SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS**: `PLAINTEXT://kafka1:9092,PLAINTEXT://kafka2:9092,PLAINTEXT://kafka3:9092`
  - Kafka brokers where schemas are stored
  - Schema Registry uses Kafka as its storage backend
  - Schemas are stored in the `_schemas` topic

- **SCHEMA_REGISTRY_KAFKASTORE_TOPIC**: `_schemas`
  - Kafka topic where schemas are persisted
  - Single-partition topic for consistency

##### Security Configuration
- **SCHEMA_REGISTRY_KAFKASTORE_SECURITY_PROTOCOL**: `PLAINTEXT`
  - Security protocol for connecting to Kafka
  - `PLAINTEXT` means no encryption (for development)

- **SCHEMA_REGISTRY_SCHEMA_REGISTRY_INTER_INSTANCE_PROTOCOL**: `http`
  - Protocol for communication between Schema Registry instances
  - Would use `https` in production for security

##### Logging
- **SCHEMA_REGISTRY_LOG4J_ROOT_LOGLEVEL**: `INFO`
  - Sets the logging level for Schema Registry
  - `INFO` provides standard operational logs
  - Other options: `DEBUG`, `WARN`, `ERROR`

- **SCHEMA_REGISTRY_DEBUG**: `true`
  - Enables debug mode for more verbose logging
  - Useful for troubleshooting

**Dependencies**: All three Kafka brokers

**Network**: `kafka-net`

**Why it's used**:
- Ensures data consistency by enforcing schemas
- Provides schema evolution and compatibility checking
- Enables versioning of data schemas
- Reduces message size by storing schemas separately
- Prevents incompatible data from being produced
- Central registry for all data contracts

**How it works**:
1. Producers register schemas before sending data
2. Schema Registry validates compatibility with existing versions
3. Consumers retrieve schemas to deserialize messages
4. All schemas are versioned and stored in Kafka's `_schemas` topic

---

### kafka-connect

```yaml
kafka-connect:
  image: confluentinc/cp-kafka-connect:7.8.0
  container_name: kafka-connect
  hostname: kafka-connect
```

**What it is**: A distributed framework for streaming data between Kafka and external systems (databases, file systems, cloud services, etc.).

**Image**: `confluentinc/cp-kafka-connect:7.8.0` - Confluent's Kafka Connect

**Ports**:
- `8083:8083` - REST API for managing connectors

**Environment Variables**:

##### Bootstrap Configuration
- **CONNECT_BOOTSTRAP_SERVERS**: `kafka1:9092,kafka2:9092,kafka3:9092`
  - Kafka brokers to connect to
  - Connect uses Kafka to coordinate distributed work and store configurations

##### Worker Configuration
- **CONNECT_GROUP_ID**: `compose-connect-group`
  - Unique identifier for this Connect cluster
  - Multiple Connect workers with the same group ID form a cluster
  - Enables distributed processing and fault tolerance

##### Internal Topics Configuration
Kafka Connect uses three internal topics to coordinate work and store state:

1. **Config Storage**:
   - **CONNECT_CONFIG_STORAGE_TOPIC**: `_connect_configs`
     - Stores connector and task configurations
   - **CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR**: `3`
     - Replicates configs across all 3 brokers for high availability

2. **Offset Storage**:
   - **CONNECT_OFFSET_STORAGE_TOPIC**: `_connect_offset`
     - Stores source connector offsets (position in source data)
   - **CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR**: `3`
     - Ensures offset data is not lost if a broker fails

3. **Status Storage**:
   - **CONNECT_STATUS_STORAGE_TOPIC**: `_connect_status`
     - Stores connector and task status information
   - **CONNECT_STATUS_STORAGE_REPLICATION_FACTOR**: `3`
     - Maintains status information across broker failures

##### Converter Configuration
Converters control how data is serialized when writing to Kafka and deserialized when reading from Kafka:

- **CONNECT_KEY_CONVERTER**: `org.apache.kafka.connect.storage.StringConverter`
  - Converts message keys to/from strings
  - Simple format for most use cases

- **CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_URL**: `http://schema-registry:8085`
  - Schema Registry URL for key conversion (if needed)
  - Not used with StringConverter but available for schema-aware converters

- **CONNECT_VALUE_CONVERTER**: `org.apache.kafka.connect.storage.StringConverter`
  - Converts message values to/from strings
  - Alternative converters: AvroConverter, JsonConverter, etc.

- **CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL**: `http://schema-registry:8085`
  - Schema Registry URL for value conversion

##### Internal Converters
- **CONNECT_INTERNAL_KEY_CONVERTER**: `org.apache.kafka.connect.json.JsonConverter`
  - Format for keys in internal topics
  - Uses JSON for human readability

- **CONNECT_INTERNAL_VALUE_CONVERTER**: `org.apache.kafka.connect.json.JsonConverter`
  - Format for values in internal topics

##### REST API Configuration
- **CONNECT_REST_ADVERTISED_HOST_NAME**: `kafka-connect`
  - Hostname advertised to other Connect workers
  - Used for distributed coordination

##### Plugin Configuration
- **CONNECT_PLUGIN_PATH**: `"/usr/share/java,/usr/share/confluent-hub-components"`
  - Directories where Connect looks for connector plugins
  - `/usr/share/java`: Built-in connectors
  - `/usr/share/confluent-hub-components`: Connectors installed via Confluent Hub

**Dependencies**: 
- All three Kafka brokers
- schema-registry (for schema-aware converters)

**Network**: `kafka-net`

**Why it's used**:
- Integrates Kafka with external systems without writing custom code
- Provides pre-built connectors for common integrations:
  - **Source Connectors**: Pull data into Kafka (e.g., JDBC, MongoDB, S3)
  - **Sink Connectors**: Push data from Kafka (e.g., Elasticsearch, HDFS)
- Distributed and scalable architecture
- Manages offset tracking and fault tolerance automatically
- Supports transformations and schema evolution

**Common Use Cases**:
- Stream database changes to Kafka (CDC - Change Data Capture)
- Export Kafka topics to data warehouses
- Sync data between microservices
- Real-time ETL pipelines

---

### prometheus

```yaml
prometheus:
  image: prom/prometheus:latest
  container_name: prometheus
  hostname: prometheus
```

**What it is**: A time-series database and monitoring system for collecting and querying metrics from Kafka brokers and other services.

**Image**: `prom/prometheus:latest` - Official Prometheus image

**Ports**:
- `9090:9090` - Prometheus web UI and query interface

**Volumes**:
- `./scripts:/etc/prometheus` - Mounts local scripts directory containing Prometheus configuration

**Command**: `--web.enable-remote-write-receiver --config.file=/etc/prometheus/prometheus.yaml`

##### Command Options:
- **--web.enable-remote-write-receiver**
  - Enables the remote write receiver endpoint
  - Allows Kafka UI and other services to push metrics to Prometheus
  - Without this, Prometheus only scrapes (pulls) metrics

- **--config.file=/etc/prometheus/prometheus.yaml**
  - Specifies the configuration file location
  - Points to the mounted prometheus.yaml in the scripts directory
  - Configuration defines what targets to scrape

**Network**: `kafka-net`

**Why it's used**:
- Collects JMX metrics from Kafka brokers (via port 9997)
- Stores time-series data for historical analysis
- Provides a query language (PromQL) for analyzing metrics
- Integrates with Kafka UI for metrics visualization
- Monitors broker health, throughput, latency, consumer lag, etc.

**Typical Metrics Collected**:
- Broker CPU and memory usage
- Message throughput (messages/sec)
- Request latency
- Partition counts
- Consumer group lag
- Replication status

**Configuration File** (prometheus.yaml):
Should contain scrape configs for Kafka brokers, e.g.:
```yaml
scrape_configs:
  - job_name: 'kafka'
    static_configs:
      - targets: ['kafka1:9997', 'kafka2:9997', 'kafka3:9997']
```

---

### filebrowser

```yaml
filebrowser:
  image: filebrowser/filebrowser:latest
  container_name: filebrowser
  hostname: filebrowser
```

**What it is**: A web-based file manager that provides a UI for browsing and managing files in Docker volumes.

**Image**: `filebrowser/filebrowser:latest` - Official FileBrowser image

**Ports**:
- `9999:80` - Web interface accessible at http://localhost:9999

**Volumes**:
1. **Data Volume**: `kafka-cluster:/srv`
   - Mounts the shared Kafka volume to `/srv` (FileBrowser's default data path)
   - Provides access to all Kafka data and logs
   - Allows browsing: `/srv/kafka1/data`, `/srv/kafka1/logs`, etc.

2. **Database File**: `./filebrowser/filebrowser.db:/database/filebrowser.db`
   - Persists FileBrowser's user database locally
   - Stores user accounts, permissions, and settings
   - Survives container restarts

3. **Configuration File**: `./filebrowser/settings.json:/.filebrowser.json`
   - Mounts custom configuration
   - Defines settings like authentication, branding, etc.

**Environment Variables**:
- **FB_BASEURL**: `/`
  - Base URL for the application
  - Set to `/` means it's accessible at the root path

- **FB_LOG**: `stdout`
  - Sends logs to standard output
  - Makes logs visible via `docker logs filebrowser`

**Network**: `kafka-net`

**Why it's used**:
- Browse Kafka data files and log segments without SSH/exec into containers
- Inspect partition data and log files
- Download logs for debugging
- View file sizes and disk usage
- Useful for development and troubleshooting
- Provides a visual interface to the shared volume

**Default Access**:
- URL: http://localhost:9999
- Default credentials (if not configured): admin/admin
- Change credentials in settings.json for security

---

## Quick Start Guide

### Step 1: Start the Cluster

Launch the entire stack:
```bash
docker-compose -f docker-compose.yml up -d
```

### Step 2: Check Service Health

Check all containers are running:
```bash
docker-compose ps
```

You should see all services in "Up" state.

### Step 3: View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f kafka1
docker-compose logs -f kafka-ui
```

### Step 4: Access Web UIs

- **Kafka UI**: http://localhost:8080 - Cluster management and monitoring
- **Prometheus**: http://localhost:9090 - Metrics and monitoring
- **FileBrowser**: http://localhost:9999 - Browse volume data and logs
- **Schema Registry**: http://localhost:8081 - Schema management API
- **Kafka Connect**: http://localhost:8083 - Connector management API

---

## Testing the Cluster


### Open the kafka sandbox environment

```bash
docker exec -it busybox  bash


# Sample producer directly on console to test
docker exec -it busybox  bash /scripts/producer.sh

# Sample consumer directly on console to test
docker exec -it busybox  bash /scripts/consumer.sh
```

### Create a Topic

Create a test topic with 3 partitions and replication factor of 3:

```bash
kafka-topics \
    --create \
    --topic test-topic \
    --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092 \
    --replication-factor 3 \
    --partitions 3
```

### List All Topics

View all topics in the cluster:

```bash
kafka-topics \
    --list \
    --bootstrap-server kafka1:9092
```

### Describe a Topic

Get detailed information about a topic (partitions, replicas, leaders):

```bash
kafka-topics \
    --describe \
    --topic test-topic \
    --bootstrap-server kafka1:9092
```

---

## Working with Producers and Consumers

### Basic Producer

Produce messages to your topic using the Kafka CLI:

```bash
kafka-console-producer \
    --broker-list kafka1:9092 \
    --topic test-topic
```

Type your messages and press **Enter** to send them. Press **Ctrl+C** to exit.

### Basic Consumer

Consume messages from the beginning of the topic:

```bash
kafka-console-consumer \
    --bootstrap-server kafka1:9092 \
    --topic test-topic \
    --from-beginning
```

This will display all messages from offset 0. Press **Ctrl+C** to exit.

---

## Advanced Producer/Consumer Scenarios

### Produce Messages with Keys

Produce messages with keys for partition routing:

```bash
kafka-console-producer \
    --broker-list kafka1:9092 \
    --topic test-topic \
    --property "parse.key=true" \
    --property "key.separator=:"
```

Type messages in the format `key1:value1`, `key2:value2`, etc.

**Example messages:**
```
user1:{"name":"Alice","age":30}
user2:{"name":"Bob","age":25}
user1:{"name":"Alice","age":31}
```

Messages with the same key will go to the same partition.

### Consumer Groups with Load Balancing

Create two consumers in the same consumer group to enable partition assignment and load balancing.

**Consumer 1:**
```bash
kafka-console-consumer \
    --bootstrap-server kafka1:9092 \
    --topic test-topic \
    --group my-consumer-group
```

**Consumer 2 (in a separate terminal):**
```bash
kafka-console-consumer \
    --bootstrap-server kafka2:9092 \
    --topic test-topic \
    --group my-consumer-group
```

**How it works:**
- Both consumers share the same group ID (`my-consumer-group`)
- Kafka automatically assigns partitions to each consumer
- With 3 partitions and 2 consumers, one consumer gets 2 partitions, the other gets 1
- Messages are load-balanced across consumers
- Each message is delivered to only one consumer in the group

---

## Cluster Management Commands

### Stop the Stack

Stop all services (data persists in volumes):
```bash
docker-compose down
```

### Stop and Remove All Data

Stop services and delete all volumes (removes all data):
```bash
docker-compose down -v
```

**Warning**: This will permanently delete all Kafka data, logs, and configurations.

### Restart a Specific Service

```bash
docker-compose restart kafka1
```

### View Resource Usage

```bash
docker stats
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Docker Network: kafka-net                │
│                                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                       │
│  │  kafka1  │  │  kafka2  │  │  kafka3  │  (KRaft Cluster)      │
│  │  :9092   │  │  :9094   │  │  :9096   │                       │
│  │  :9093   │  │  :9095   │  │  :9097   │                       │
│  │  :9997   │  │          │  │          │                       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                       │
│       │             │             │                              │
│       └─────────────┴─────────────┘                              │
│                     │                                             │
│       ┌─────────────┼─────────────────────────┐                 │
│       │             │                         │                  │
│  ┌────▼────┐  ┌────▼─────┐  ┌──────▼──────┐ ┌▼──────────┐      │
│  │ Schema  │  │  Kafka   │  │  Kafka UI   │ │Prometheus │      │
│  │Registry │  │ Connect  │  │   :8080     │ │  :9090    │      │
│  │  :8081  │  │  :8083   │  │             │ │           │      │
│  └─────────┘  └──────────┘  └─────────────┘ └───────────┘      │
│                                                                   │
│  ┌──────────────┐  ┌─────────────────┐                          │
│  │ FileBrowser  │  │    busybox      │                          │
│  │    :9999     │  │  (init helper)  │                          │
│  └──────────────┘  └─────────────────┘                          │
│                                                                   │
│  Volume: kafka-cluster                                           │
│  ├── kafka1/                                                     │
│  │   ├── data/  (topic partitions)                              │
│  │   └── logs/  (application logs)                              │
│  ├── kafka2/                                                     │
│  └── kafka3/                                                     │
└───────────────────────────────────────────────────────────────────┘
```

---

## Key Features

### High Availability
- 3-node cluster with replication factor of 3
- Survives single broker failure
- Automatic leader election via KRaft

### Monitoring & Management
- Kafka UI for visual management
- Prometheus for metrics collection
- JMX endpoints on all brokers
- FileBrowser for data inspection

### Data Integration
- Schema Registry for schema management
- Kafka Connect for external system integration
- Pre-configured connectors

### Development-Friendly
- Automatic topic creation
- Sample data loading
- Easy access to all services
- Persistent data storage

---

## Production Considerations

For production deployments, consider these changes:

1. **Security**:
   - Enable SSL/TLS for all listeners
   - Configure SASL authentication
   - Secure JMX endpoints
   - Use secrets management for credentials

2. **Replication**:
   - Keep `KAFKA_MIN_INSYNC_REPLICAS: 2`
   - Set transaction log replication to 3
   - Increase `KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS`

3. **Resources**:
   - Set JVM heap sizes
   - Configure resource limits in Docker
   - Allocate sufficient disk space

4. **Networking**:
   - Use proper DNS names
   - Configure external listeners for client access
   - Set up load balancers

5. **Monitoring**:
   - Enable authentication on Prometheus
   - Set up alerting rules
   - Configure log aggregation

---

## Troubleshooting

### Cluster won't start
- Check that CLUSTER_ID is identical across all brokers
- Verify KAFKA_CONTROLLER_QUORUM_VOTERS lists all 3 nodes
- Check logs: `docker-compose logs kafka1`

### Can't connect from host
- Verify port mappings are correct
- Check KAFKA_ADVERTISED_LISTENERS
- Test with: `telnet localhost 9092`

### Topics not created
- Check kafka-init-topics logs
- Verify brokers are ready before topic creation
- Manually create: `kafka-topics --create ...`

### Permissions errors
- Ensure init-kafka completed successfully
- Check volume permissions: `docker exec kafka1 ls -la /mnt/shared`

---

## Conclusion

This Docker Compose setup provides a complete, production-like Kafka environment for development and testing. It includes all necessary components for a modern Kafka deployment with monitoring, management, and integration capabilities.
