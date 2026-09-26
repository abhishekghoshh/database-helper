# PostgreSQL Source Code Architecture

## Overview

The PostgreSQL source tree maps 1:1 to runtime subsystems: `postmaster`, `access` (storage + AMs + WAL), `executor`, `optimizer`, `parser`, `replication`, `storage` (buffers, locks, IPC), `utils` (caches, snapshots). This file is a reading map: feature → subsystem → key files → runtime behavior.

> **Accuracy note:** file paths below reflect the long-stable tree layout (v12–v17). Verify exact paths against the checked-out major version before citing line numbers; subsystem responsibilities are stable even when files move.

See also:

- [PostgreSQL Architecture](./postgresql-architecture.md)
- [Query Execution Internals](./query-execution-internals.md)
- [PostgreSQL Internals Projects](./postgresql-internals-projects.md) (build/debug/trace labs)

## Tree Map

```text
src/backend/
  postmaster/     supervisor, auth dispatch, bgworker launcher
  libpq/          wire protocol (frontend/backend messages)
  parser/         gram.y/scan.l → analyzer → query tree
  rewrite/        rules, views, RLS expansion
  optimizer/      paths → plans (planner, costsize, clauses,geqo)
  executor/       node* (seqscan, hashjoin...), tuplestore, DSM gather
  access/
    heap/         heapam: tuples, HOT, pruning, vacuumlazy
    nbtree|hash|gist|gin|brin|spgist  index AMs
    transam/      xact, clog(pg_xact), multixact, xlog(WAL), twophase
  storage/
    buffer/       bufmgr, buffer descriptors, freelist
    ipc/          shmem, procsignal, procarray, sinval, dsm, latch
    lmgr/         lock manager, deadlock detector, predicate locks, spin
    page/         bufpage, itemptr, checksums
    smgr/         storage manager: md.c (files), fsm, vm
  catalog/        relcache/catcache, pg_class/attribute/index accessors
  replication/    walsender, walreceiver, logical (decoding, worker, launcher)
  utils/
    mmgr/         MemoryContext arenas
    time/         tqual (visibility), snapshots
    cache/        relcache, catcache, sinval catchup
    adt/          datatypes, jsonb, tsvector...
  postmaster/     checkpointer, bgwriter, walwriter, archiver, autovacuum, stats
  tsearch/        full-text search
  foreign/        FDW core + postgres_fdw (contrib)
```

Contrib/extensions live in `contrib/` (pg_stat_statements, pgcrypto, postgres_fdw, amcheck) and `src/test/` holds isolation/regression suites (`src/test/isolation/` for concurrency specs — the best executable documentation of SSI/deadlock behavior).

## Tracing a Query Through Source

```text
psql parse ('SELECT ... WHERE id=1')
  → parser/gram.y → analyze.c (Query tree, RTEs)
  → rewriteHandler (rules/views/RLS)
  → optimizer: paths (index vs seq via costsize + pg_statistic),
     plan (planner.c:create_plan)
  → executor: ExecInitNode tree → ExecProcNode loop
  → access/heap + nbtree: buffer pins (bufmgr), visibility (tqual.c)
  → transam: XID, snapshots; xlog: WAL on writes
```

Debug/trace: build with `--enable-debug --enable-cassert`, attach `gdb` to a backend (`SELECT pg_backend_pid()`), break on `exec_simple_query` / `heap_update` / `heap_delete`; `perf` + `auto_explain` for production-safe tracing.

## Build / Read / Extend

```bash
./configure --enable-debug --enable-cassert --prefix=$HOME/pgdev
make -j$(nproc) && make install
initdb -D $HOME/pgdev-data -E UTF8 --data-checksums
```

Read order for contributors: `tqual.c` (visibility) → `heapam.c`+`vacuumlazy.c` (versions/lifecycle) → `bufmgr.c` (buffers) → `xlog.c` (WAL) → `lock.c`+`deadlock.c` (locks) → `planner.c`+`costsize.c` (plans) → `walsender.c` (replication). Extension APIs (`PG_FUNCTION_INFO_V1`, index/table AMs, bgworkers, custom scans) are the safe contribution surface — core patches need hackers-list review + isolation tests.

## Interview Questions

### Advanced

- Where does tuple visibility live in source? — `utils/time/tqual.c` (`HeapTupleSatisfiesMVCC`) + `access/heap/heapam_visibility.c`, driven by snapshots from `procarray.c` and status in `transam/slru` (pg_xact).
- Buffer pin vs buffer lock in code? — Pin: `PinBuffer` refcount (eviction protection). Lock: `LockBuffer` shared/exclusive (consistent access). Different files, different lifetimes.

## Key Takeaways

- Subsystem → directory → key file is a stable mental index; verify paths per major version.
- Visibility, vacuum, buffers, WAL, locks, planner, replication: seven files explain 80% of behavior.
- Extend via extension APIs; patch core only with tests + community review.
