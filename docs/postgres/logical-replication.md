# Logical Replication

## Overview

Logical replication ships *row changes* (not WAL bytes) via publications/subscriptions, decoded by logical decoding. Tables — not clusters — are the unit, which enables selective sync, cross-version upgrades, and CDC feeds. This file explains the worker pipeline, identity, conflicts, and limits.

See also:

- [Replication Internals](./replication-internals.md)
- [Logical Decoding and CDC](./logical-decoding-cdc.md)
- [Partitioning Internals](./partitioning-internals.md)

## Why This Matters

Zero-downtime major-version upgrades, selective multi-region tables, and Postgres→warehouse pipelines all run on logical replication. Its conflict model (last-writer-wins-ish, actually first-arriver with errors) surprises physical-replication veterans.

## Architecture / Decoding / Origins / Publications / Subscriptions / Workers

```mermaid
flowchart LR
    WAL[Primary WAL] --> Slot[Logical slot + pgoutput]
    Slot --> Walsender[WALSender]
    Walsender --> Sub[Subscription: apply workers]
    Sub --> Tables[Subscriber tables]
```

- **Publication** (`CREATE PUBLICATION p FOR TABLE a, b WITH (publish = 'insert,update,delete')`): which tables/changes to send. DDL is *not* replicated (data only).
- **Subscription** (`CREATE SUBSCRIPTION s CONNECTION ... PUBLICATION p`): leader apply worker + per-table sync workers + parallel apply workers (v16+ `streaming = parallel`).
- **Replication origin** (`pg_replication_origin`): progress tracking per subscription so restarts resume and loops are detected.
- **Initial sync**: per-table `COPY` snapshot under a exported snapshot, then catch-up replay — large tables sync one at a time; monitor `pg_stat_subscription`.

## Replica Identity / Conflicts / Schema Changes / Limitations

- **Replica identity** (`REPLICA IDENTITY FULL/USING INDEX`): UPDATE/DELETE need the old key to find the subscriber row. No PK → must use FULL (whole-row matching, slow) or updates/deletes fail to apply. *Every logically-replicated table needs a PK or explicit identity.*
- **Conflicts**: concurrent writes on both sides → apply errors (unique violations, missing rows), subscription stops. There is no automatic conflict resolution — design single-writer-per-table or idempotent consumers.
- **Schema changes**: DDL doesn't replicate; adding a column primary-side breaks/stalls apply until subscriber schema matches. Run coordinated migrations (expand-first, backfill, contract).
- **Limitations**: no sequences (gaps/divergence), no large-object replication, no DDL/triggers-on-subscriber firing by default (`ENABLE ... REPLICA` controls), initial-sync copy is single-threaded per table.

## Logical Decoding Plugins / CDC Role

`pgoutput` (built-in) emits the logical protocol; `wal2json`/`decoderbufs`/`Debezium` serve external consumers. PostgreSQL-as-CDC-source architecture lives in [Logical Decoding and CDC](./logical-decoding-cdc.md).

## What Actually Happens Internally?

`UPDATE` on published table → WAL commit → slot decodes to (old-key, new-row) → sender streams → subscriber apply worker opens transaction, applies via SPI → origin LSN advances. Conflict (subscriber row changed) → apply worker error → subscription `disabled`-ish state until skipped/patched (`ALTER SUBSCRIPTION ... SKIP (lsn = ...)` v15+).

## Hands-on Experiment

```sql
-- primary: CREATE PUBLICATION pub FOR TABLE t;
-- replica: CREATE SUBSCRIPTION sub CONNECTION 'host=primary dbname=db' PUBLICATION pub;
SELECT * FROM pg_stat_subscription;  -- sync state per table
UPDATE t SET v=1 WHERE id=1;         -- watch apply on replica; break replica PK to see conflict stop
```

## Troubleshooting

### Symptom: subscription stuck, `latest_end_lsn` not advancing

Apply conflict. **Diagnose:** subscriber logs (unique violation / missing tuple), `pg_stat_subscription_tables` per-table state. **Fix:** reconcile rows, `SKIP` the poisoned LSN, fix dual-write design.

## Interview Questions

### Intermediate

- Why does every table need replica identity? — UPDATE/DELETE ship old keys; without PK/identity the subscriber can't locate the row.
- What replicates: data, schema, sequences? — Data only. Schema via migrations, sequences need separate coordination.

### Advanced

- Physical vs logical conflict models? — Physical: no conflicts possible (byte-identical replay). Logical: concurrent writes conflict at row level with no resolver — architecture must avoid dual writes.
- How do you do a zero-downtime major upgrade with logical replication? — Publish from old, subscribe on new version, cut over writes, promote; DDL freeze during catch-up.

## Key Takeaways

- Logical replication is table-granular row shipping with single-writer assumptions.
- Replica identity + coordinated DDL are the operational contract.
- For external consumers (Kafka/warehouse), prefer the CDC pipeline over subscriptions.
