# Database Security

## Theory

### Authentication

Authentication verifies the identity of a user or application connecting to the database — confirming "who you are" via credentials such as passwords, certificates, tokens, or integrated identity providers (LDAP, Active Directory, OAuth). Strong authentication (e.g., multi-factor, certificate-based) reduces the risk of unauthorized access even if credentials leak.

### Authorization

Authorization determines "what an authenticated user is allowed to do" — controlling access to specific databases, tables, columns, or operations. It's typically enforced through a permission model (roles/privileges) evaluated after authentication succeeds. Authentication and authorization are distinct: you can be authenticated (identity confirmed) but not authorized to perform a given action.

### Roles

A role is a named collection of privileges that can be granted to users or other roles, simplifying permission management at scale. Instead of granting the same set of privileges to every user individually, you assign a role once and manage permissions centrally by updating the role.

```sql
-- Create a role and grant it to a user
CREATE ROLE read_only;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO read_only;
GRANT read_only TO analyst_user;
```

- **Advantages:** centralized permission management, easier onboarding/offboarding, consistent access policies
- **Disadvantages:** role explosion if not designed carefully, can obscure exactly which privileges a user effectively has

### Privileges

Privileges are specific permissions to perform an action on a database object — e.g., `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `EXECUTE`, or administrative privileges like `CREATE` or `DROP`. Following the principle of least privilege — granting only what's necessary — reduces the attack surface and limits the blast radius of a compromised account.

```sql
GRANT SELECT, INSERT ON orders TO app_user;
REVOKE DELETE ON orders FROM app_user;
```

### Encryption at Rest

Encryption at rest protects data stored on disk (data files, backups, logs) by encrypting it so that anyone with raw filesystem or storage access cannot read the data without the decryption key. This is typically implemented via transparent data encryption (TDE) at the storage engine level or disk/volume-level encryption.

### Encryption in Transit

Encryption in transit protects data as it moves across the network between client and database (or between replicas), typically using TLS/SSL. This prevents man-in-the-middle attacks and eavesdropping on credentials or sensitive data while in flight.

| Aspect | Encryption at Rest | Encryption in Transit |
|---|---|---|
| Protects against | Physical disk theft, unauthorized filesystem access | Network eavesdropping, MITM attacks |
| Typical mechanism | TDE, disk/volume encryption | TLS/SSL |
| Performance impact | Minimal (hardware-accelerated) | Slight handshake/connection overhead |
| Covers | Data files, backups, logs | Data on the wire |

### Auditing

Auditing records who accessed or modified what data and when, providing a trail for compliance (e.g., SOC 2, HIPAA, PCI-DSS) and forensic investigation after a security incident. Audit logs typically capture login attempts, privilege changes, and DML/DDL statements, and should themselves be protected from tampering.

- **Advantages:** compliance support, forensic traceability, deterrent against misuse
- **Disadvantages:** storage overhead for audit logs, potential performance impact if auditing is overly verbose

### SQL Injection (Overview)

SQL injection is an attack where untrusted input is concatenated directly into a SQL query, allowing an attacker to alter the query's logic — potentially exfiltrating data, bypassing authentication, or modifying/deleting records. The primary defense is using parameterized queries/prepared statements instead of string concatenation, along with input validation and least-privilege database accounts.

```sql
-- Vulnerable: string concatenation
-- "SELECT * FROM users WHERE username = '" + input + "'"
-- If input is:  ' OR '1'='1
-- Resulting query becomes: SELECT * FROM users WHERE username = '' OR '1'='1'

-- Safe: parameterized query
SELECT * FROM users WHERE username = ?;
```

### Interview Questions

- **Q: What is the difference between authentication and authorization?**
  A: Authentication verifies identity ("who are you"), while authorization determines what actions that verified identity is permitted to perform ("what can you do").
- **Q: Why are roles preferred over granting privileges directly to individual users?**
  A: Roles centralize privilege management — updating a role's permissions automatically applies to every user assigned that role, simplifying audits and reducing inconsistent access.
- **Q: How does encryption at rest differ from encryption in transit, and do you need both?**
  A: Encryption at rest protects stored data from unauthorized disk/storage access, while encryption in transit protects data moving across the network; most secure systems need both since they defend against different attack vectors.
- **Q: How would you prevent SQL injection in an application?**
  A: Always use parameterized queries or prepared statements (never string-concatenate user input into SQL), validate/sanitize input, and run the database account with least-privilege permissions.
- **Q: What is the principle of least privilege and why does it matter for database security?**
  A: Granting only the minimum permissions necessary for a user or service to perform its function, which limits the damage possible if credentials are compromised.
- **Q: What would you look for in a database audit log after a suspected breach?**
  A: Unusual login times/locations, failed authentication attempts, privilege escalation events, and unexpected DML/DDL activity on sensitive tables.
- **Q: A junior developer suggests storing passwords in plain text "since the database is encrypted at rest anyway." Why is this insufficient?**
  A: Encryption at rest only protects against raw disk access; anyone with valid database query access (or an SQL injection exploit) would still see plaintext passwords — passwords should be hashed with a strong algorithm (e.g., bcrypt) regardless of disk encryption.

