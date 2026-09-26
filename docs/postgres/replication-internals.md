# Replication Internals

## Overview

Physical replication ships WAL bytes from primary to standbys and replays them into identical clusters. This file explains senders, receivers, slots, sync modes, lag anatomy, conflicts, timelines, and failover — the mechanics behind every read replica and HA setup.

See also:

- [WAL: Write-Ahead Logging](./wal.md)
- [Logical Replication](./logical-replication.md)
- [Crash Recovery Internals](./crash-recovery-internals.md) (replay shares recovery code)
- [Real-World PostgreSQL Architecture](./real-world-postgres-architecture.md)

## Why This Matters

Replica lag, split-brain, WAL disk-full from slots, and failed promotions are replication-mechanics incidents. This file gives the LSN-level vocabulary to diagnose them.

## Architecture / Physical / Streaming / Sender / Receiver / Slots

```mermaid
flowchart LR
    Primary[Primary: WAL] --> Sender[WAL Sender]
    Sender --> Net[Network]
    Net --> Receiver[WAL Receiver]
    Receiver --> StandbyWAL[Standby pg_wal]
    StandbyWAL --> Startup[Startup process: replay]
    Startup --> Standby[Standby heap]
```

- **WAL sender** (`walsender`, one per standby): streams from `pg_wal` (or decodes from memory) starting at the standby's requested LSN.
- **WAL receiver** (`walreceiver` on standby): writes incoming WAL to standby `pg_wal`, fsyncs per `wal_receiver_*` settings.
- **Startup process** on standby: continuously replays (`recovery` mode) — replay *is* crash recovery running forever.
- **Replication slots** (`primary_slot_name` + `pg_replication_slots`): primary-side reservation — slot's `restart_lsn` pins WAL so a lagging/disconnected standby never loses history it hasn't confirmed. Inactive slots pin forever: the disk-full vector.

## Standbys / Hot Standby / Read Replicas / Cascading

- **Hot standby** (`hot_standby = on`): standby accepts read queries while replaying — with conflict rules below.
- **Read replicas**: hot standbys used for read scaling; all writes still go to primary (single-writer architecture).
- **Cascading**: standby with `hot_standby = on` + its own senders serves downstream standbys — reduces primary fan-out, adds cascade lag.

## Sync vs Async / Commit Modes / Lag / Replay

| Mode | Commit ack condition | Lag exposure |
|---|---|---|
| Async (default) | primary flush only | unbounded (network + replay) |
| `remote_write` | standby received (not flushed) | small, power-loss window on standby |
| `on` / `remote_apply` (sync) | standby flushed / applied | commit latency = slowest sync standby |

`synchronous_standby_names = 'FIRST 1 (a,b)'` quorum semantics; `synchronous_commit` per-transaction overrides (`SET LOCAL synchronous_commit TO LOCAL` for non-critical writes on a sync cluster).

**Lag anatomy** (`pg_stat_replication`: `sent_lsn`, `write_lsn`, `flush_lsn`, `replay_lsn`): network lag = sent−write; disk lag = write−flush; apply lag = flush−replay (long queries, conflicts, heavy writes block replay — replay is single-threaded per database in classic recovery).

## Conflicts / Feedback / Delay / Consistency

On hot standbys, replay (DDL, vacuum removals, exclusive locks) can conflict with running read queries: PostgreSQL cancels the *query* (`max_standby_archive_delay`/`max_standby_streaming_delay`, "canceling statement due to conflict with recovery") or delays *replay* (causing lag). `hot_standby_feedback = on` tells the primary about standby snapshots so vacuum doesn't remove rows the standby still needs — at the cost of primary bloat (feedback pins `xmin`).

## Failover / Promotion / Timelines / `pg_rewind`

- **Promotion** (`pg_ctl promote` / `pg_promote()`): standby stops recovery at a consistent LSN, starts a **new timeline** (history fork) so old-primary WAL can never confuse it.
- **Timelines** (`.history` files): every promotion branches history; replicas follow via `recovery_target_timeline = 'latest'`.
- **`pg_rewind`**: resynchronizes an old primary as a standby by rewinding un-replicated changes — avoids full re-basebackup after failed failovers.
- **Split-brain**: two primaries accepting writes (failed fencing) → divergent timelines requiring manual reconciliation. Patroni/operator fencing exists to make this structurally impossible, not unlikely.

## What Actually Happens Internally?

Failover with Patroni: leader lock lost → fence old primary → `pg_ctl promote` on sync standby → timeline fork → connection router ( PgBouncer/Haproxy) repoints → old primary `pg_rewind`s and rejoins as standby. Every step is WAL/timeline mechanics, not magic.

## Hands-on Experiment

```sql
-- primary:
SELECT * FROM pg_stat_replication;           -- sender state per standby
SELECT slot_name, active, replay_lsn FROM pg_replication_slots;
-- standby:
SELECT pg_is_in_recovery();                  -- true
SELECT pg_last_wal_replay_lsn(), pg_last_xact_replay_timestamp();
-- generate load on primary; watch replay_lsn gap grow and drain
```

## Troubleshooting

### Symptom: replica lag growing, network fine

**Diagnose:** which LSN gap (write/flush/replay)? Check standby conflicts in logs, long standby queries (`pg_stat_activity` on standby), replay-blocked DDL. **Fix:** cancel long standby queries or raise delay knobs (accept more lag), tune `max_standby_*_delay`, add `hot_standby_feedback` (watch primary bloat), scale standby IOPS (replay is I/O-bound on heavy writes).

### Symptom: primary disk filling, WAL not recycling

Dead replication slot. **Fix:** `SELECT pg_drop_replication_slot('dead')` after confirming no standby needs it; alert on retained-bytes metric permanently.

## Interview Questions

### Intermediate

- Sender vs receiver vs startup process? — Sender streams, receiver persists to standby WAL, startup replays into the standby heap.
- Why do slots exist if TCP streaming already delivers WAL? — Delivery ≠ durability of history: slots reserve WAL across disconnects so a returning standby resumes instead of needing a rebuild.

### Advanced

- Sync commit `remote_apply` vs `on`? — `on`: flushed on standby (durable, maybe not visible). `remote_apply`: replayed (visible to standby reads). Latency vs freshness.
- Why is replay single-threaded a lag factor, and what helps? — One replay stream per database serializes heavy writes; helps: smaller transactions, less write amplification, standby IOPS, v15+ parallel apply for logical (physical stays serial).

## Key Takeaways

- Replication = WAL shipping + perpetual recovery. Every lag/conflict/slot behavior follows.
- Slots trade disk for resume-ability — monitor retained bytes as a first-class metric.
- Sync modes trade commit latency for durability/freshness per transaction — choose deliberately.
