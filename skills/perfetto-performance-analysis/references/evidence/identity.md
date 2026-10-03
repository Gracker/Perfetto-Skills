# Evidence identity

Use stable identifiers in every query result, finding, and report. Names are
labels for humans; they are not identity because they can collide, change, or
be reused during a trace.

## Trace identity

- `trace_path`: absolute input path used for the run.
- `trace_sha256`: SHA-256 of the exact trace bytes.
- `trace_side`: stable comparison label such as `baseline`, `candidate`, or
  `trace_a`; never infer it from file order later.
- `trace_start_ts` and `trace_end_ts`: bounds returned by the probe.

## Process and thread identity

- Process: retain `upid`, `pid`, and process name together. Prefer `upid` for
  joins inside one trace; a reused `pid` is not sufficient.
- Thread: retain `utid`, `tid`, thread name, and owning `upid`. Prefer `utid`
  for joins inside one trace.
- When a user supplies only a package or name, list candidates and resolve the
  target from overlapping lifetime and activity. Record ambiguity instead of
  silently selecting the first row. `perfetto_skill.py` and `--query-id` runs
  do this through the same identity gate as SmartPerfetto: a Skill whose SQL
  filters by process name verifies a supplied name with
  `process_identity_resolver`, runs only on one verified process, and records
  the gate's status, confidence, candidates, and warnings in its evidence.
  When the resolver itself fails, a `verify_if_present` Skill still runs and
  records its identity as `unresolved` with the reason, as in SmartPerfetto.
- A verified explicit UPID, or a PID that maps to one UPID, scopes the run to
  that exact process. The evidence carries `applied_process_scope` (mode
  `exact_upid`, the UPID, trace SHA-256 and side) only for target rows; global
  or peer context rows record their role in `scope_provenance` instead. A
  Skill whose SQL cannot run under an exact scope is refused before any query,
  with the supported exact Skills named; a step declared unavailable for an
  exact scope is recorded `unavailable` and the result is `partial`.

## Event identity

Every evidence row must retain `ts`, `dur`, units, process/thread identifiers,
and any domain key such as frame token, startup ID, layer ID, transaction ID,
slice ID, or track ID. For intervals, use half-open bounds `[ts, ts + dur)`.
Never compare identifiers across different `trace_side` values as if they were
global IDs.

## Query provenance

Store the trace hash, SQL asset path/hash, parameters, trace-processor version,
execution time, row count, and truncation limit with the result. A finding cites
stable evidence IDs derived from those saved results, not copied prose.
