# Missing data and negative evidence

An empty result can mean the behavior did not happen, the trace did not record
it, the query used the wrong identity or interval, or the platform exposes a
different signal. Keep these states separate.

## Availability test

Before treating zero rows as negative evidence, prove all of the following:

1. The required table, module, counter, track, or event family is present.
2. The signal is supported by this Android, kernel, browser, framework, vendor,
   and trace-processor version.
3. The requested scope overlaps the trace: correct `upid`/`utid`, package,
   layer, frame token, and `[start_ts, end_ts)` interval.
4. A positive control or neighboring sample shows the data source is populated
   where expected.
5. The query completed without timeout, parse error, truncation, or fallback
   that changed its meaning.

Only then may an empty result become negative evidence for that exact requested
scope. It is never proof about time or processes outside that scope.

## Report states

- `observed`: matching evidence exists.
- `not_observed`: availability was proven and the bounded query returned none.
- `missing_evidence`: the required source is absent or unsupported.
- `out_of_scope`: the requested identity or time range is not covered.
- `query_failed`: execution or interpretation failed.

Do not replace these with zero. Report the failed availability condition and a
capture or query change that would make the claim testable.
