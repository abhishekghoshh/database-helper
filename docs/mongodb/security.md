# Security

## Authentication

Authentication verifies the identity of a client connecting to MongoDB before allowing any operations. MongoDB supports several mechanisms: SCRAM (Salted Challenge Response Authentication Mechanism, the default username/password mechanism), x.509 certificate authentication, and enterprise-only mechanisms like LDAP and Kerberos. Authentication is disabled by default on a fresh standalone install but should always be enabled (`--auth` or `security.authorization: enabled`) before exposing MongoDB beyond a trusted local environment.

```javascript
// Create an authenticated user with SCRAM
db.createUser({
  user: "appUser",
  pwd: "strongPasswordHere",
  roles: [{ role: "readWrite", db: "ecommerceDb" }]
})
```

```java
// Spring Boot: configuring authenticated MongoDB connection
spring.data.mongodb.uri=mongodb://appUser:strongPasswordHere@localhost:27017/ecommerceDb?authSource=admin
```

**Differences:**

| Concept | Authentication | Authorization |
|---|---|---|
| Question answered | "Who are you?" | "What are you allowed to do?" |
| Mechanism examples | SCRAM, x.509, LDAP, Kerberos | Roles and privileges (RBAC) |
| Failure result | Connection/login rejected | Operation rejected despite valid login |

**Interview Questions:**
- What authentication mechanisms does MongoDB support? — MongoDB supports SCRAM (default username/password), x.509 certificate authentication, and enterprise-only mechanisms like LDAP and Kerberos.
- Why should authentication always be enabled in production, even on an internal network? — Internal networks can still be breached, misconfigured, or accessed by insider threats, so enabling authentication ensures only verified clients can perform operations regardless of network trust assumptions, following defense-in-depth principles.
- How does x.509 authentication differ from SCRAM? — x.509 authenticates clients using cryptographic certificates rather than a shared username/password, which is useful for mutual TLS setups and avoids managing passwords, while SCRAM uses a salted challenge-response protocol based on a username and password.

## Authorization

Authorization determines what an authenticated user is permitted to do, enforced in MongoDB through Role-Based Access Control (RBAC). Every user is granted one or more roles, and each role bundles a set of privileges (actions on specific resources, like `find` on a particular collection). MongoDB ships built-in roles (e.g. `read`, `readWrite`, `dbAdmin`, `clusterAdmin`) and also supports fully custom roles for fine-grained control.

```javascript
// Grant a custom role with narrowly scoped privileges
db.createRole({
  role: "orderReaderOnly",
  privileges: [
    { resource: { db: "ecommerceDb", collection: "orders" }, actions: ["find"] }
  ],
  roles: []
})
```

**Advantages:**
- Enforces least-privilege access, limiting blast radius of compromised credentials
- Built-in roles cover most common scenarios without custom configuration

**Interview Questions:**
- How does role-based authorization work in MongoDB? — Each user is assigned one or more roles, and each role bundles a set of privileges (specific actions on specific resources), so a user's effective permissions are the union of privileges granted by all their assigned roles.
- What is the principle of least privilege and how does RBAC support it? — The principle of least privilege means granting only the minimum access necessary to perform a task; RBAC supports this by letting administrators define narrowly scoped custom roles (e.g., read-only access to one collection) rather than broad, all-encompassing permissions.
- How would you grant a service account read-only access to a single collection? — Create a custom role with a single privilege granting `find` (and similar read) actions scoped to that specific collection's resource, then assign that role to the service account's user.

## Users and Roles

Users are created per-database (though a user's `authSource` can be a shared `admin` database) and are assigned one or more roles that may themselves be scoped to different databases. MongoDB stores user credentials and role assignments in the `admin.system.users` and `admin.system.roles` collections. Managing users typically involves `db.createUser()`, `db.updateUser()`, `db.dropUser()`, and `db.grantRolesToUser()`.

```javascript
use admin
db.createUser({
  user: "reportingUser",
  pwd: "anotherStrongPassword",
  roles: [
    { role: "read", db: "ecommerceDb" },
    { role: "read", db: "analyticsDb" }
  ]
})
```

**Interview Questions:**
- Where does MongoDB store user credentials and role definitions? — MongoDB stores user credentials and role assignments in the `admin.system.users` and `admin.system.roles` collections.
- Can a single user have roles that span multiple databases? How? — Yes, when creating a user you can assign an array of role objects each specifying its own `db`, allowing a single user to hold different roles scoped to different databases.
- What is `authSource` and why does it matter when authenticating? — `authSource` specifies which database holds the user's credentials to authenticate against (often `admin` even when accessing a different database), and it matters because the client must point to the correct database or authentication will fail.

## Role-Based Access Control (RBAC)

RBAC is MongoDB's authorization model where privileges (allowed actions on specific resources) are grouped into roles, and roles are assigned to users rather than granting individual privileges directly. This indirection makes access management scalable: you can update a role's privileges once and have it apply to every user holding that role, and you can compose custom roles from other roles.

```mermaid
flowchart LR
    User1[appUser] --> Role1[readWrite role]
    User2[reportingUser] --> Role2[read role]
    Role1 --> Priv1[Privileges: find, insert, update, remove on ecommerceDb]
    Role2 --> Priv2[Privileges: find on ecommerceDb, analyticsDb]
```

**Advantages:**
- Simplifies permission management at scale compared to per-user privilege grants
- Custom roles allow precise least-privilege modeling for microservices

**Interview Questions:**
- Why is RBAC preferred over granting privileges directly to individual users? — RBAC lets administrators update a role's privileges once and have the change automatically apply to every user holding that role, making permission management scalable and consistent compared to managing privileges per-user.
- How would you design roles for a microservices architecture with several services accessing shared collections? — Create narrowly scoped custom roles per service reflecting exactly the collections and actions that service needs (e.g., an order service gets read/write on `orders` only), assigning each service its own dedicated user with only its required role(s).
- What built-in MongoDB roles exist for common administrative tasks? — Built-in roles include `read`, `readWrite`, `dbAdmin`, `userAdmin`, `clusterAdmin`, `backup`, and `restore`, among others, covering common database and cluster administration needs without requiring custom role definitions.

## TLS/SSL

TLS/SSL encrypts data in transit between MongoDB clients, drivers, and cluster members (replica set/shard internal traffic), preventing eavesdropping and man-in-the-middle attacks on the network. MongoDB is configured with `net.tls.mode` (e.g. `requireTLS`) along with certificate and key file paths, and clients must be configured with matching TLS options and trusted CA certificates.

```yaml
# mongod.conf: enabling TLS
net:
  tls:
    mode: requireTLS
    certificateKeyFile: /etc/ssl/mongodb.pem
    CAFile: /etc/ssl/ca.pem
```

```java
// Spring Boot connection string requiring TLS
spring.data.mongodb.uri=mongodb://appUser:pass@host:27017/ecommerceDb?tls=true
```

**Advantages:**
- Protects credentials and sensitive data from network-level interception
- Can also be used for mutual authentication via x.509 client certificates

**Disadvantages:**
- Adds CPU overhead for encryption/decryption and certificate management complexity

**Interview Questions:**
- What network-level threats does TLS protect MongoDB against? — TLS protects against eavesdropping and man-in-the-middle attacks by encrypting data in transit between clients, drivers, and cluster members, preventing attackers on the network from reading or tampering with traffic.
- What MongoDB configuration options control TLS enforcement? — The `net.tls.mode` setting (e.g., `requireTLS`) along with `certificateKeyFile` and `CAFile` paths in `mongod.conf` control whether and how TLS is enforced for client and internal cluster connections.
- How can TLS certificates also be used for client authentication? — MongoDB supports x.509 certificate authentication, where a client presents a valid TLS certificate signed by a trusted CA as proof of identity instead of (or in addition to) a username/password.

## Encryption at Rest

Encryption at rest protects data stored on disk (data files, journal, logs, backups) from being read directly if physical storage or disk images are stolen or improperly accessed. MongoDB Enterprise offers native WiredTiger encryption at rest using AES-256, integrated with a key management system (KMIP) or a local key file; alternatively, encryption can be achieved at the filesystem/disk layer (e.g. LUKS, encrypted EBS volumes) independent of MongoDB itself.

```yaml
# mongod.conf: enabling native encryption at rest (Enterprise)
security:
  enableEncryption: true
  encryptionKeyFile: /etc/mongodb/keyfile
```

**Differences:**

| Approach | Layer | Availability |
|---|---|---|
| Native WiredTiger encryption | Storage engine | MongoDB Enterprise only |
| Filesystem/disk encryption (e.g. LUKS, encrypted EBS) | OS/infrastructure | Available on Community edition |

**Interview Questions:**
- What is the difference between encryption at rest and TLS in transit? — Encryption at rest protects data stored on disk from being read if the physical storage or backups are stolen, while TLS in transit protects data as it moves across the network between clients and servers; the two address different threat surfaces and are typically used together.
- What options exist for encrypting MongoDB data at rest on the Community edition? — Community edition lacks native WiredTiger encryption, so encryption at rest must be achieved at the filesystem or disk layer, such as using LUKS or encrypted cloud disk volumes (e.g., encrypted EBS).
- What key management approaches does MongoDB Enterprise support for encryption at rest? — Enterprise supports a local key file or integration with an external key management system via the KMIP protocol for managing the master encryption key used by native WiredTiger encryption.

## Auditing (Overview)

Auditing (a MongoDB Enterprise feature) records system events such as authentication attempts, authorization checks, CRUD operations, and administrative actions, providing a trail for compliance and security forensics. Audit filters let you narrow the captured events (e.g. only failed authentication attempts, or actions by a specific user) to control log volume, and output can be written to a file, syslog, or console in JSON or BSON format.

```javascript
// Example audit filter: only log authentication failures
{
  atype: "authenticate",
  "param.result": { $ne: 0 }
}
```

**Advantages:**
- Provides an immutable trail for compliance requirements (SOC 2, HIPAA, PCI-DSS)
- Filters allow focused auditing without excessive log noise

**Interview Questions:**
- What kinds of events can MongoDB's auditing feature capture? — Auditing can capture authentication attempts, authorization checks, CRUD operations, and administrative actions such as user or role changes.
- Why would you configure an audit filter rather than logging every event? — An audit filter narrows captured events (e.g., only failed authentication attempts or actions by a specific user) to reduce log volume and noise, making the audit trail more manageable and focused on relevant security events.
- What compliance scenarios typically require database auditing? — Compliance frameworks like SOC 2, HIPAA, and PCI-DSS typically require an auditable trail of who accessed or modified sensitive data and when, which MongoDB's auditing feature helps satisfy.

## Client-Side Field Level Encryption

Client-Side Field Level Encryption (CSFLE) encrypts specific document fields on the client, before they are ever sent to MongoDB, so that even database administrators or anyone with direct data file access cannot read the plaintext values. Encryption keys are managed via a key management system (local, AWS KMS, Azure Key Vault, GCP KMS) and never exposed to the server; MongoDB stores only ciphertext for the designated fields, while the driver transparently encrypts/decrypts them for authorized clients holding the correct keys.

```mermaid
sequenceDiagram
    participant App
    participant Driver as Driver (CSFLE)
    participant KMS
    participant Mongo as MongoDB Server
    App->>Driver: insert({ssn: "123-45-6789"})
    Driver->>KMS: fetch data encryption key
    KMS-->>Driver: return key
    Driver->>Driver: encrypt ssn field locally
    Driver->>Mongo: insert({ssn: <ciphertext>})
    Mongo-->>Driver: stored (server never sees plaintext)
```

**Advantages:**
- Protects highly sensitive fields (SSNs, payment data) even from privileged database access
- Supports queryable encryption variants for equality searches on encrypted fields (in newer versions)

**Disadvantages:**
- Adds application/driver complexity and key management overhead
- Encrypted fields have restricted query capabilities compared to plaintext fields

**Interview Questions:**
- How does Client-Side Field Level Encryption differ from encryption at rest and TLS? — CSFLE encrypts specific fields on the client before they're ever sent to the server, so even privileged database administrators or anyone with raw data file access only see ciphertext, whereas encryption at rest and TLS protect data at the storage and network layers but leave data readable to anyone with legitimate server-side access.
- Who manages the encryption keys in a CSFLE setup, and why does that matter? — Encryption keys are managed via an external key management system (local key file, AWS KMS, Azure Key Vault, or GCP KMS) and are never exposed to the MongoDB server, which matters because it ensures the database itself never has the ability to decrypt the protected fields.
- What are the query limitations on fields encrypted with CSFLE? — Encrypted fields generally cannot be used in most query operators or indexed for range queries; only newer "queryable encryption" variants support limited equality (and in some versions range) queries directly on encrypted fields.
