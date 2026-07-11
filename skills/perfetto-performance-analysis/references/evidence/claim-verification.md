# Claim verification

Classify each conclusion before assigning confidence.

## Claim ladder

1. **Observation**: a bounded query returned a value or interval.
2. **Correlation**: two observations overlap or vary together.
3. **Mechanism evidence**: identity-linked state, waker, Binder transaction,
   lock owner, fence, buffer, frame, callstack, or policy signal explains how
   one stage delayed another.
4. **Verified root cause**: the mechanism covers the claimed symptom interval,
   survives competing explanations, and changes the outcome enough to matter.

Timing overlap alone stops at correlation. A long slice name, high CPU value,
low frequency, D-state, or missing frame is not by itself a verified cause.

## Verification record

For every material claim record: claim ID, class, affected trace/process/thread,
time range, cited evidence IDs, mechanism, alternatives tested, missing data,
confidence, and what would falsify it. Recommendations must target the verified
mechanism and distinguish app, framework, system, vendor, and capture changes.

## Cross-trace rule

Analyze every trace independently first. Compare only facts with equivalent
definitions, units, identities, windows, refresh budgets, topology, and source
availability. A delta is an observation; it becomes causal only after a
side-specific mechanism explains it.
