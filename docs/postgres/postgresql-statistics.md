# PostgreSQL Statistics

## Overview

The planner's cost model eats statistics: per-column histograms, most-common values, null fractions, correlation, and extended multivariate objects. `ANALYZE` samples tables into `pg_statistic`; autovacuum refreshes it. Stale or missing stats are the root cause of most "bad plan" incidents.

See also:

- [Query Execution Internals](./query-execution-internals.md)
- [VACUUM Internals](./vacuum-internals.md)
- [Partitioning Internals](./partitioning-internals.md)

## Why This Matters

A planner with wrong row estimates picks wrong join orders, wrong join algorithms, and wrong scan types simultaneously. Statistics freshness is a reliability property, not a nicety.

## Why Stats Exist / `ANALYZE` / `pg_statistic` / `pg_stats`

`ANALYZE` samples (`default_statistics_target` × 300 rows, default 30k sample) and stores distributions in `pg_statistic` (opaque arrays); the human-readable view is `pg_stats`. Autovacuum's analyze phase refreshes on write thresholds — which means *read-mostly bulk-loaded tables can go stale*: a nightly bulk load with no subsequent writes never trips the analyze threshold.

```sql
SELECT attname, null_frac, n_distinct, correlation,
       most_common_vals, most_common_freqs, histogram_bounds
FROM pg_stats WHERE tablename = 'orders';
```

## Targets / Histograms / MCVs / Null Fraction / Correlation / NDV

| Stat | Used for | Failure mode when wrong |
|---|---|---|
| Histogram bounds | range selectivity (`WHERE created_at > X`) | skewed ranges misestimated |
| MCVs + freqs | equality on popular values (`status = 'shipped'`) | rare-value queries get popular-value plans |
| `null_frac` | `IS NULL` / join nullability | misplanned outer joins |
| `correlation` | index-vs-heap order alignment | wrong index-scan/bitmap choice |
| `n_distinct` | join cardinality, `GROUP BY` sizing | catastrophic multi-join blowups |

Raise per-column targets where it matters: `ALTER TABLE t ALTER COLUMN status SET STATISTICS 1000; ANALYZE t;` — targeted, not global (global 1000 slows every ANALYZE).

## Extended Statistics / Dependencies / Multivariate / MCV Combos

Single-column stats assume independence — false for `(city, zip)`, `(make, model)`. `CREATE STATISTICS` builds:

- **Functional dependencies** (`city → zip`): planner knows filtering one constrains the other.
- **N-distinct on combinations**: correct multi-column `GROUP BY` sizing.
- **MCV lists on combinations**: correlated equality selectivity.

```sql
CREATE STATISTICS s (dependencies) ON city, zip FROM addresses;
ANALYZE addresses;
```

Required reading for any schema with correlated dimensions; the #1 fix for "estimates fine per-column, 1000× off combined".

## Misestimation / Cardinality Problems / Partitioned Tables / Freshness

- **Detection**: `EXPLAIN ANALYZE` estimate-vs-actual per node; `auto_explain` with `log_analyze` in production for the real parameterized plans.
- **Partitioned tables**: stats exist per-partition *and* (v14+ improved) on the partitioned parent; cross-partition estimates still weaker — check parent `relkind = 'p'` stats after bulk partition loads.
- **Freshness**: `SELECT last_analyze, last_autoanalyze FROM pg_stat_user_tables;` — NULL or ancient on a churning table means autovacuum-analyze thresholds are wrong for it (lower scale factors per-table).

## Autovacuum and ANALYZE

Analyze is cheaper than vacuum and independently triggerable: `ANALYZE t` takes `SHARE UPDATE EXCLUSIVE` (doesn't block writes). For ETL tables: explicit `ANALYZE` at end of load job beats any threshold tuning.

## Hands-on Experiment

```sql
CREATE TABLE s(id serial, status text);
INSERT INTO s(status) SELECT CASE WHEN g % 100 = 0 THEN 'rare' ELSE 'common' END FROM generate_series(1,100000) g;
ANALYZE s;
EXPLAIN SELECT * FROM s WHERE status = 'rare';   -- small estimate
SET default_statistics_target = 1; ANALYZE s;
EXPLAIN SELECT * FROM s WHERE status = 'rare';   -- estimate degrades; reset after
RESET default_statistics_target;
```

## Troubleshooting

### Symptom: good plan yesterday, seq-scan + hash-join blowup today, no code change

**Diagnose:** `last_autoanalyze` vs bulk-load time; `EXPLAIN` estimate-vs-actual; check for new correlated predicates. **Fix:** manual `ANALYZE`, per-column targets, extended statistics; schedule ANALYZE in the load job.

## Interview Questions

### Intermediate

- What does `ANALYZE` physically do? — Samples rows, builds histograms/MCVs/correlation into `pg_statistic`; updates `pg_class.reltuples/relpages`.
- Why do bulk-loaded tables go stale despite autovacuum? — Analyze thresholds count *subsequent* modifications; a load followed by silence trips nothing.

### Advanced

- When do extended statistics beat higher per-column targets? — Correlated columns: per-column stats are accurate individually but independence assumption multiplies errors.
- How do you prove misestimation in production? — `auto_explain` with analyze+buffers for the parameterized plan, estimate-vs-actual per node.

## Key Takeaways

- Statistics are sampled approximations with freshness and independence assumptions — know all three failure modes.
- Targeted `STATISTICS` targets + `CREATE STATISTICS` + in-job `ANALYZE` beat global knobs.
- Every bad-plan investigation starts at estimate-vs-actual.
