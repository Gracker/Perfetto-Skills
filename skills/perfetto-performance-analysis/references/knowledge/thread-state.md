# Thread-state interpretation

Use the generated [thread-state blocked-reason guide](../generated/knowledge/knowledge-thread-state-blocked-reason.template.md)
with identity-linked `thread_state`, sched, waker, and optional blocked-function
evidence.

- `Running`: scheduled on a CPU; attribute CPU time, not wall time.
- `R`/Runnable: eligible but waiting for CPU; investigate runqueue pressure,
  priority, affinity, capacity, and wakers.
- `S`: interruptible sleep; it may represent Binder, futex, condition wait,
  timer sleep, or normal idleness. Resolve the mechanism.
- `D`: uninterruptible sleep; it can involve storage, page fault, driver, GPU,
  DMA, or other kernel waits. It is not synonymous with disk IO.

Blocked-function and kernel stack evidence is sampled and version-dependent.
Correlate it to the same `utid` and overlapping interval. A futex symbol alone
does not prove lock contention; identify owner/waker or report the chain break.
