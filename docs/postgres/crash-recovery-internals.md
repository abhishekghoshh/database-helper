# Crash Recovery Internals

## Overview

After any unclean shutdown, the startup process replays WAL from the last checkpoint's redo pointer, reconstructing dirty pages forward to consistency. This file explains REDO mechanics, torn-page defense, and recovery performance.

See also:

- [WAL: Write-Ahead Logging](./wal.md)
- [Checkpoints and Background Writer](./checkpoints-background-writer.md)
- [Backup and Recovery Internals](./backup-recovery-internals.md)

## Why This Matters

Crash recovery is the proof of the WAL design: committed data survives anything except WAL loss. Recovery time is the single-instance RTO floor — size checkpoints and WAL accordingly.

## After Crash / REDO / Checkpoint Records / Start-End Points / Dirty Pages / Durability

```mermaid
flowchart LR
    Control[pg_control: last redo LSN] --> Scan[Scan WAL forward]
    Scan --> Redo[REDO each record: apply to pages]
    Redo --> FPI[Full-page images fix torn pages]
    FPI --> End[End-of-WAL: consistent, new checkpoint]
```

1. Startup reads `pg_control` for the last checkpoint's redo LSN.
2. Replays every WAL record after it (heap/index mutations, FPIs, commit markers).
3. Dirty pages in buffers at crash time are irrelevant — replay reconstructs them from WAL + surviving files.
4. Writes an end-of-recovery checkpoint; postmaster opens for connections.

`fsync` + `full_page_writes` are the load-bearing guarantees: without durable WAL fsyncs, "committed" is fiction; without FPIs, torn pages (half-written 8 KB) can't be repaired by delta replay.

## Torn Pages / Corruption / Performance / Conflicts

- **Torn pages**: OS writes 8 KB in sectors; crash mid-page leaves halves from different eras. First-touch FPI after each checkpoint gives replay a whole-page baseline — the reason disabling `full_page_writes` needs page-atomic storage proof.
- **Recovery performance**: proportional to WAL since last checkpoint (hence `max_wal_size`/`checkpoint_timeout` set RTO) + FPI volume + storage replay bandwidth. `recovery_prefetch`/`recovery_init_sync_method` tune replay I/O.
- **Corruption**: checksum mismatch during replay halts recovery at the bad record — restore from base + archive skipping past it (data loss window) or page-level salvage (`zero_damaged_pages` as last resort, with acknowledged data loss).

## Hands-on Experiment

```sql
SHOW data_checksums;  -- on for modern initdb
CHECKPOINT;
-- kill -9 a backend-heavy pgbench run's postmaster (test host!), restart, watch:
-- LOG: database system was not properly shut down; automatic recovery in progress
-- LOG: redo starts at ... ; LOG: database system is ready (replay time visible)
```

## Interview Questions

### Intermediate

- Why does restart take minutes after a crash but seconds after clean shutdown? — Clean shutdown checkpointed everything; crash replays all WAL since the last redo pointer.
- What exactly do full-page images repair? — Torn pages: replaying deltas onto a half-written page diverges; FPI restores the whole page first, then deltas apply cleanly.

## Key Takeaways

- REDO-forward from the last checkpoint is the entire recovery model — everything else is tuning its cost.
- `full_page_writes` + honest fsync are non-negotiable on ordinary storage.
- Checkpoint cadence sets crash RTO; measure replay time, don't assume it.
