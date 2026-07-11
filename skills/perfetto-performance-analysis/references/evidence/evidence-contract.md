# Evidence contract

Apply these rules to every workflow and report.

## Identity

Bind evidence to a trace side, process (`upid`, `pid`, name), thread (`utid`,
`tid`, name), and time range whenever the trace exposes them. Keep identifiers
alongside names because names can collide or change.

## Availability

Probe required tables, modules, tracks, and trace bounds before querying. Treat
missing instrumentation, unsupported Android/Perfetto versions, and out-of-range
windows as `missing_evidence`. An empty query is negative evidence only after
the required source and scope are proven available.

## Claims

Classify each statement as observation, correlation, mechanism evidence,
hypothesis, or verified root cause. A verified root cause must cite evidence
that covers the claimed trace, process/thread, event window, and causal
mechanism. Timing overlap alone is correlation.

## Units and aggregation

Keep Perfetto timestamps and durations in nanoseconds in saved artifacts.
Convert units only in presentation fields and label the conversion. Avoid
double-counting parent/child slices; use exclusive/self time for attribution
when the workflow provides it.

## Comparisons

Analyze each side independently, preserve side-specific availability, then
compare like-for-like metrics. Do not normalize away different data sources,
refresh rates, CPU topologies, trace windows, or vendor instrumentation.

## Output

Assign stable evidence IDs, cite them from findings, and list unresolved
alternatives and missing evidence in `limitations`. Follow
`assets/report-schema.json` from the Skill root.

