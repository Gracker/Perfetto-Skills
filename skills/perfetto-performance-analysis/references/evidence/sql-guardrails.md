# PerfettoSQL guardrails

Run `scripts/perfetto_sql_guardrails.py` before executing authored or modified
SQL. The validator is static: it can reject unsafe setup and require a proof
reference, but it cannot inspect interval rows without a trace.

## Blocking SPAN_JOIN invariants

For every `SPAN_JOIN` or `SPAN_LEFT_JOIN`:

1. Drop the virtual table before recreating it.
2. If both inputs are partitioned, use the same identity key. One input may be
   intentionally global and unpartitioned.
3. Prove that each input is non-overlapping inside its effective partition.
   `PARTITIONED` isolates entity matching; it does not merge or repair
   overlapping rows.
4. Put a non-empty proof reference immediately before the create statement:

```sql
DROP TABLE IF EXISTS joined;
-- perfetto-span-join-non-overlap-proof: fixture sched-frequency-inputs
CREATE VIRTUAL TABLE joined
USING SPAN_JOIN(
  left_spans PARTITIONED utid,
  right_spans PARTITIONED utid
);
```

The comment records where the proof lives; it is not proof by assertion. A
reviewable dynamic witness for one input is:

```sql
WITH ordered AS (
  SELECT
    partition_id,
    ts,
    IIF(dur = -1, trace_end() - ts, dur) AS effective_dur,
    LEAD(ts) OVER (
      PARTITION BY partition_id
      ORDER BY ts, dur
    ) AS next_ts
  FROM input_intervals
)
SELECT partition_id, ts, effective_dur, next_ts
FROM ordered
WHERE next_ts < ts + effective_dur
LIMIT 1;
```

Zero rows prove this invariant only for that input, trace, scope, and rendered
query. Preserve the query, parameters, trace hash, and result with the fixture
or assertion. If overlaps are real, merge them with an appropriate stdlib
interval operator or choose an operator whose semantics support overlaps.

## Advisories

The validator also reports non-blocking review prompts for:

- `LIKE` instead of `GLOB` or exact equality;
- raw duration arithmetic that may mishandle `dur = -1`;
- start-only interval boundaries;
- non-idempotent reusable object creation;
- direct `args` table parsing instead of `EXTRACT_ARG`.

Advisories need contextual review and do not automatically make an existing
catalog query invalid. Use `--strict` when authoring new SQL to make advisories
fail the command.

```bash
python3 <skill-root>/scripts/perfetto_sql_guardrails.py query.sql
python3 <skill-root>/scripts/perfetto_sql_guardrails.py \
  query.sql --format json --strict
```
