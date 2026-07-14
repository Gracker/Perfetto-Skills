GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-thread-state-blocked-reason.template.md
Source SHA-256: dd8f6737c3f5a62a376d1d44aa26b635232e13c6eb9a02f4b4289fa1ac38632e
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

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

Evidence strength:

| Signal | What it proves | Confidence |
| --- | --- | --- |
| `D/DK + io_wait=1` | The task entered an I/O wait path such as `io_schedule()` | High for I/O wait |
| `D/DK + IO/page-cache blocked_function` | The task is blocked near a storage, filesystem, or page-cache path | Medium, needs slice/block-I/O correlation |
| `D/DK` only | Uninterruptible kernel wait | Low; do not call it disk I/O alone |
| `S + epoll/poll` | Looper or poll wait, often idle or waiting for an event | Exclusion/ambiguous evidence |

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
| `epoll_wait`, `do_epoll_wait`, `poll_schedule_timeout` | Thread waits for fd events | Looper idle, network/socket wait, async callback wait | Main Looper slices, input/log events, request telemetry |
| `hrtimer_nanosleep`, `clock_nanosleep` | Explicit sleep timer | `Thread.sleep()` / `SystemClock.sleep()` | App slice or stack proving caller |
| `pipe_wait`, `pipe_read` | Waiting on pipe data or pipe buffer | Subprocess or local IPC | Peer process/thread, pipe-related slices |
| `inet_*`, `tcp_*`, `sk_wait_*` | Socket/network wait in kernel | Main-thread network, DNS/TCP wait, socket backpressure | Network telemetry, packet trace, OkHttp/Cronet spans |

## Reporting Rule

When using this knowledge in a finding, connect it to the current trace:

> `D + io_wait=1 + filemap_read` means the thread was in an I/O wait path while
> the kernel tried to satisfy a file-backed read. In this trace it accounts for
> X ms in the target window; next verify file/page-fault/block-I/O evidence
> before naming the app-level root cause.
