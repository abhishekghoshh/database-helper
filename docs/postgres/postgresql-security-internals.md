# PostgreSQL Security Internals

## Overview

Roles, privileges, `pg_hba.conf`, SCRAM/TLS, RLS, function security, and auditing form defense in depth: authenticate strongly, authorize minimally, encrypt transit/at-rest, audit everything. This file connects each control to its subsystem and failure mode.

See also:

- [PostgreSQL Connection Internals](./postgresql-connection-internals.md)
- [Advanced PostgreSQL Features](./advanced-postgres-features.md) (RLS)
- [Configuration Internals](./configuration-internals.md)

## Why This Matters

The common breach path is stale credentials + overprivileged app role + unencrypted transit + no audit trail. Each section below removes one link.

## Roles / Inheritance / Membership / Privileges / HBA / AuthN vs AuthZ

- **Roles** (`pg_roles`): users and groups unified; `INHERIT`, `LOGIN`, `CONNECTION LIMIT`. Membership (`pg_auth_members`) composes least-privilege sets: `app_reader`, `app_writer`, `migrator`, `readonly_analytics`.
- **Privileges**: per-object (`GRANT SELECT ON`, `ALTER DEFAULT PRIVILEGES` for future objects) — default-deny; audit with `information_schema.role_table_grants`.
- **`pg_hba.conf`**: network admission (first-match) — authentication. Grants: authorization. Confusing them (authenticated ≠ authorized) causes both outages and holes.

## SCRAM / TLS / Certificates / RLS / Functions / Search Path / Least Privilege / Auditing

- **SCRAM-SHA-256 + TLS 1.2+** (`ssl = on`, `ssl_cert_file/key_file`, `ssl_min_protocol_version`): passwords never transit in clear; `sslmode=verify-full` on clients. Rotate with `password_encryption = scram-sha-256`.
- **mTLS service auth**: `cert` + `clientcert=verify-full` + `pg_ident.conf` mapping for service identities.
- **RLS**: tenant isolation in the database; combine with per-tenant roles + `SET app.tenant` from a trusted middleware (never client-supplied without verification).
- **Functions**: `SECURITY DEFINER` runs as owner — `SET search_path` fixed + schema-qualified objects + revoke `PUBLIC` execute; prefer `SECURITY INVOKER` unless privilege escalation is the point.
- **Least privilege**: app roles get table/column grants only; migrations via separate elevated role in CI; superuser never in app DSNs; `pg_read_all_data`-style defaults denied.
- **Auditing**: `pgaudit` extension (session/object logging) + `log_connections/disconnections` + `log_statement='ddl'` minimum; ship to immutable store. Cloud: combine with KMS-managed keys, at-rest encryption, secret rotation (Vault/SSM), and network policy (private subnets, no public 5432).

## Hands-on Experiment

```sql
CREATE ROLE app_writer NOLOGIN; GRANT CONNECT ON DATABASE app TO app_writer;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_writer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_reader;
-- connect as each role; verify \z shows minimal grants; attempt escalation and watch denial
```

## Troubleshooting

### Symptom: `FATAL: no pg_hba.conf entry for host`

Rule ordering or missing line, not credentials. **Fix:** add the specific `(host, db, user, CIDR, scram-sha-256)` line above broader rejects, `pg_reload_conf()`, retest.

## Interview Questions

### Intermediate

- AuthN vs AuthZ in PG terms? — `pg_hba.conf` + SCRAM/TLS prove identity; GRANTs + RLS + object ownership decide access.
- Why is `SECURITY DEFINER` dangerous with a mutable `search_path`? — Function resolves unqualified names in the *caller's* path; attacker-created objects shadow intended ones → privilege escalation.

### Advanced

- Design tenant isolation for 10k tenants? — Single cluster: RLS + per-tenant app role mapping + `app.tenant` GUC from verified JWT; separate clusters when compliance/noisy-neighbor demands physical isolation.

## Key Takeaways

- Layer: mTLS/SCRAM → least-privilege roles → RLS → encrypted transit/at-rest → pgaudit trail.
- Defaults deny; grants explicit; superuser absent from apps.
- Secrets rotate; logs ship immutably; HBA changes reload safely.
