GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-lock-contention.template.md
Source SHA-256: 6cfd4a03ea657ae1cc6ddee22f9dc76a3b4d4a2af314bc7454348ec22a46fc70
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Knowledge Lock Contention Template

Portable methodology extracted from the SmartPerfetto strategy library.

# Lock Contention on Android

## Mechanism

When multiple threads compete for the same lock, all but the holder must wait. On Android, lock contention follows an escalation path:

1. **Thin lock (fast path)**: ART uses a CAS (compare-and-swap) operation. If uncontended, acquisition costs ~1 instruction. No kernel involvement.
2. **Fat lock (contended)**: When a thin lock is contended, ART inflates it to a fat lock backed by a **futex** (Fast Userspace muTEX). The waiting thread enters kernel sleep via `futex_wait`.
3. **Kernel wait**: The blocked thread is removed from the CPU run queue entirely. It cannot do any work until the lock holder releases and the kernel wakes it.

When lock contention occurs on the main thread, it directly steals frame budget time. The main thread cannot process input, run animations, or draw while waiting for a lock.

## Monitor Contention (Java Locks)

Java `synchronized` blocks use ART monitor locks. When contended:
- A `monitor contention with <owner>` slice appears on the blocked thread
- The `android_monitor_contention` table provides structured data: blocking_method, blocked_method, waiter_count, blocking_thread_name
- High waiter_count indicates a hot lock with multiple threads competing

## Futex Contention (Native/Kernel Level)

Native locks (pthread_mutex, std::mutex) and inflated Java monitors both use futex under the hood:
- blocked_function = `futex_wait_queue` in thread_state indicates kernel-level lock wait
- Longer futex waits suggest the lock holder is doing significant work while holding the lock

## Deadlock Pattern

When Thread A holds Lock1 and waits for Lock2, while Thread B holds Lock2 and waits for Lock1, both threads enter `S(futex)` state indefinitely. In traces, look for two threads both showing extended `futex_wait_queue` states pointing at each other. The `android_monitor_contention_chain` table can reveal these circular dependencies.

## Common Causes

| Source | Why It's Contended |
|--------|-------------------|
| ContentProvider.onCreate() | Holds a global lock during initialization; queries from other threads block |
| synchronized database access | Single-writer lock on SQLite; UI thread queries block on background writes |
| SharedPreferences commit() | Holds lock during disk I/O; other reads/writes block |
| Room database transactions | Write transactions hold exclusive lock; concurrent reads wait |
| Custom singletons with synchronized | Any shared state guarded by a single lock |

## Trace Signatures

| What to Look For | Meaning |
|-----------------|---------|
| `monitor contention with <owner>` slice | Java monitor lock blocked, shows who holds it |
| `android_monitor_contention` table | Structured contention data with methods and thread names |
| `android_monitor_contention_chain` | Multi-hop blocking chains (A blocks B blocks C) |
| blocked_function = `futex_wait_queue` | Kernel-level lock wait |
| Thread state = `S` with futex blocked_function | Thread sleeping on contended lock |

## Typical Solutions

- **Reduce synchronized scope**: Hold locks for the minimum necessary duration. Move I/O and computation outside locked sections.
- **Use concurrent data structures**: Replace synchronized HashMap with ConcurrentHashMap, synchronized List with CopyOnWriteArrayList for read-heavy access.
- **Move I/O out of locked sections**: Never perform disk reads, network calls, or binder IPC while holding a lock.
- **Use ReadWriteLock**: For read-heavy patterns, ReentrantReadWriteLock allows concurrent reads while serializing writes.
- **Use StrictMode**: Enable `detectAll()` during development to catch lock contention and disk I/O on the main thread.
- **Avoid nested locks**: Acquire locks in a consistent order across all threads to prevent deadlocks.
- **Use async patterns**: Replace synchronized access with coroutines + Mutex or Channel for structured concurrency.
