# ANR and blocking

## Purpose

Explain unresponsiveness through thread state, blocking chains, Binder, locks, futex, IO, and scheduler evidence.

## Inputs

Require a trace, target process/thread, ANR or blocked time range, and any external ANR metadata.

## Availability gate

Confirm thread_state coverage, blocked-function availability, Binder/lock/IO signals, and exact target identity.

## Evidence sequence

Measure target thread states; resolve D/S/Runnable/Running intervals; build supported waker/Binder/lock chains; correlate long slices, GC, IO, and CPU contention. Search `references/generated/` for `anr_analysis`, `blocking_chain_analysis`, and `binder_root_cause` after export.

## Interpretation boundaries

Treat `blocked_function`, D-state, and IO-like waits according to kernel semantics. Do not label every futex wait lock contention or every D-state storage IO.

## Deep dives

Follow only chains with matching identity and overlapping intervals; report broken links explicitly.

## Report requirements

Report target state distribution, supported blocking chain, unresolved gaps, root-cause confidence, and missing instrumentation.

