# Kafbat UI

**Kafbat UI** (formerly `provectus/kafka-ui`) is the active, community-maintained open-source web UI for Apache Kafka. It serves as the direct successor to the now-inactive Provectus project.


## Project Status

| Feature | Provectus (`provectus/kafka-ui`) | Kafbat (`kafbat/kafka-ui`) |
| :--- | :--- | :--- |
| **Status** | 🔴 Inactive / Abandoned | 🟢 Active / Maintained |
| **Github link** | [provectus/kafka-ui](https://github.com/provectus/kafka-ui) | [kafbat/kafka-ui](https://github.com/kafbat/kafka-ui) |
| **Security** | Unpatched Vulnerabilities (CVEs) | Actively Patched |
| **Version** | Stalled at v0.7.x | v1.0+ |
| **Docker Image** | `provectuslabs/kafka-ui` | `ghcr.io/kafbat/kafka-ui` |

## Why the Split?
The original creator (Provectus) paused development on the project around late 2023. To prevent the tool from dying, the core open-source maintainers and community forked the repository. They rebranded it as **Kafbat** to facilitate continued security updates, bug fixes, and feature development.

## Key Improvements in Kafbat
* **Security:** Critical CVEs found in old dependencies have been resolved.
* **RBAC:** Enhanced Role-Based Access Control and ACL management.
* **Smart Filters:** Better filtering capabilities for topic messages.
* **Bug Fixes:** Resolution of long-standing issues from the original repo.

## Migration Guide
Since Kafbat is a direct fork, it is largely backward compatible. In most cases, migration only requires changing the Docker image source.

### Docker Compose
Update your `docker-compose.yaml`:

```yaml
services:
  kafka-ui:
    # OLD: image: provectuslabs/kafka-ui:latest
    # NEW:
    image: ghcr.io/kafbat/kafka-ui:latest
    container_name: kafka-ui
    ports:
      - "8080:8080"
    environment:
      - KAFKA_CLUSTERS_0_NAME=local
      - KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=kafka:9092
```