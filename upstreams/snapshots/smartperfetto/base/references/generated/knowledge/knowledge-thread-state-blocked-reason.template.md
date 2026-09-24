GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-thread-state-blocked-reason.template.md
Source SHA-256: 2765f8388c714fc05aaf7cac63dd2deffc819a50d7ab5e900667c3103da4f5a5
Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

# Knowledge Thread State Blocked Reason Template

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
<!-- Copyright (C) 2024-2026 Gracker (Chris) | the portable runtime -->

# Thread State Blocked Reason

## Evidence Boundary

Perfetto `thread_state` blocking evidence comes from two scheduler signals:

- `sched_switch` creates the state interval. `D` / `DK` means uninterruptible
  sleep; it does not by itself prove disk I/O.
- `sched/sched_blocked_reason` adds `io_wait` and `blocked_function`.
  `blocked_function` is the kernel wchan single frame returned for the blocked
  task. It is not an atrace slice and not a full kernel call stack.

The Android common kernel emits that event for TASK_UNINTERRUPTIBLE only:
android14-6.1 `kernel/sched/core.c` guards it inside `try_to_wake_up` with
`if (READ_ONCE(p->__state) & TASK_UNINTERRUPTIBLE) trace_sched_blocked_reason(p);`,
and android16-6.12 guards it inside `__schedule` with
`if (block && (prev_state & TASK_UNINTERRUPTIBLE) && trace_sched_blocked_reason_enabled())`.
So `blocked_function` exists on `D` / `DK` / `I` rows and is NULL on every `S`
row, on every device, whatever the recording config. A socket receive, an epoll
wait and a `Object.wait()` are all `S`, so none of them can be named this way.
Attribute an `S` wait by its WAKE SOURCE instead: Perfetto records `waker_utid`
and `irq_context` on the first `R`/`R+` row after the sleep, and combining that
with the sleeping thread's role (and, where the trace has it, rx-packet
correlation) produces a candidate class — never a proven cause. The Skill for
that is `process_thread_wait_sources_in_range`; `blocking_chain_analysis` exposes
the same `wake_source` / `wait_class` columns on its waker chain.

Evidence strength:

| Signal | What it proves | Confidence |
| --- | --- | --- |
| `D/DK + io_wait=1` | The task entered an I/O wait path such as `io_schedule()` | High for I/O wait |
| `D/DK + IO/page-cache blocked_function` | The task is blocked near a storage, filesystem, or page-cache path | Medium, needs slice/block-I/O correlation |
| `D/DK` only | Uninterruptible kernel wait | Low; do not call it disk I/O alone |
| `S` (any) | Interruptible wait: Looper/epoll, socket receive, lock or timed wait | No `blocked_function` exists; attribute by wake source, not by function name |
| `S` + irq-context wake + network-role thread | A receive-side wake is plausible | Candidate only; a timer expiry looks identical |
| `S` + irq-context wake + rx packet within the correlation window | Receive activity at the same moment | `trace_direct:packet_activity`; still not proof this wake carried that packet |

Rows grouped by `blocked_function` are flat aggregates. Multiple rows such as
`filemap_read`, `io_schedule`, and `ext4_*` are sibling buckets, not a nested
stack. If a full off-CPU stack is needed, capture `linux.perf` callstack samples
on scheduler events with a target-thread filter; do not sample every
`sched_switch` globally without filtering.

## Function Families

| `blocked_function` pattern | What is happening | Common Android scenario | Next evidence |
| --- | --- | --- | --- |
| `filemap_read`, `filemap_get_pages`, `do_read_cache_page` | Kernel is reading file-backed pages through page cache; a miss can wait for storage | Cold resource/dex/so read, mmap-backed startup load | File/DB slices, page-fault rows, block I/O, memory pressure |
| `filemap_fault`, `do_page_fault`, `handle_mm_fault` | Page fault on mapped file or anonymous memory; may load a missing page | DEX/OAT/AppImage/so mmap, large asset first touch | `page_fault_in_range`, class-loading slices, reclaim/kswapd |
| `wait_on_page_bit*`, `folio_wait_bit*` | Thread waits for a page or folio to become unlocked/up-to-date | Concurrent read of same page, page-cache miss, writeback | Neighbor filemap events, block completion latency |
| `io_schedule`, `submit_bio*`, `blk_mq*`, `blk_finish_plug` | Block layer I/O was submitted or is being waited on | Storage queue latency, flush/read/write | `block_io_analysis`, disk queue depth, device-level latency |
| `ext4_*`, `f2fs_*`, `erofs_*`, `dm_*`, `ufshcd*`, `mmc_*` | Filesystem, device mapper, or UFS/eMMC path | Filesystem read/write, dm-verity/dm-crypt, storage stalls | Filesystem events, block I/O, storage health |
| `do_fsync`, `SyS_fsync`, `ksys_fsync`, `vfs_fsync` | Forced persistence to storage | SQLite WAL/checkpoint, SharedPreferences commit, file commit | DB/SP slice, file path, block flush latency |
| `__alloc_pages_slowpath`, `try_to_free_pages`, `shrink_*`, `compact_*` | Allocation entered reclaim or compaction | Memory pressure, page-cache eviction causing later I/O | LMK/reclaim/kswapd/PSI, process RSS growth |
| `futex_wait*`, `__mutex_lock*`, `rwsem_*`, `pthread_mutex*` | Thread is waiting for a userspace/kernel lock | Java monitor, native mutex, SharedPreferences awaitLoadedLocked | lock contention chain, owner thread slices |
| `binder_ioctl`, `binder_thread_read` | Binder client or server thread is in binder driver | Synchronous IPC wait or binder pool wait | Binder txn peer, server thread state, system_server load |
| `binder_wait_for_work` | Binder pool is idle waiting for incoming work | Normal binder thread-pool idle; suspicious only on main thread | Thread role, binder transaction context |
| `epoll_wait`, `do_epoll_wait`, `poll_schedule_timeout` | Only reachable when the poll path itself entered an uninterruptible wait; an ordinary Looper or socket poll is `S` and produces no row at all | Rare; do not expect it for Looper idle or network waits | Wake source of the `S` wait, Main Looper slices, request telemetry |
| `hrtimer_nanosleep`, `clock_nanosleep` | Explicit sleep timer | `Thread.sleep()` / `SystemClock.sleep()` | App slice or stack proving caller |
| `pipe_wait`, `pipe_read` | Waiting on pipe data or pipe buffer | Subprocess or local IPC | Peer process/thread, pipe-related slices |
| `inet_*`, `tcp_*`, `sk_wait_*` | Visible only for D-state socket paths, for example `tcp_sendmsg` blocking under memory pressure; ordinary receive waits are `S` and are not visible through `blocked_function` at all | Send-side backpressure or allocation stall inside the socket path | Wake source of the `S` receive wait, `android_network_packets`, network telemetry, OkHttp/Cronet spans |

## Reporting Rule

When using this knowledge in a finding, connect it to the current trace:

> `D + io_wait=1 + filemap_read` means the thread was in an I/O wait path while
> the kernel tried to satisfy a file-backed read. In this trace it accounts for
> X ms in the target window; next verify file/page-fault/block-I/O evidence
> before naming the app-level root cause.
