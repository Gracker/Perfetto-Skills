GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-binder-ipc.template.md
Source SHA-256: 0a1c550faa9c9931e3fd5cc8a215bef30dd2256d4cfce0d5d1e38eaa8084a6f8
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Knowledge Binder Ipc Template

Portable methodology extracted from the SmartPerfetto strategy library.

# Android Binder IPC

## Mechanism

Binder is Android's primary inter-process communication mechanism. A synchronous binder call works as follows:

1. **Client thread** issues a `binder transaction` and **sleeps** (blocked in kernel)
2. **Kernel** transfers the call data to the target (server) process
3. **Server thread** wakes up, executes the requested method, and produces a result
4. **Kernel** copies the result back to the client
5. **Client thread** wakes up and continues execution

During the entire round-trip, the client thread cannot do anything else. When this happens on the main thread, it cannot process input events, run animations, or draw frames.

## Why It Blocks the UI

The main thread is single-threaded for UI work. A synchronous binder call on the main thread means:
- No Choreographer callbacks fire (frame deadlines missed)
- Input events queue up (touch latency increases)
- Animations freeze

The blocking duration depends entirely on the server side -- the client has no control over how long the server takes to respond.

## Common Slow Servers

| Server Process | Service | Why It's Slow |
|---------------|---------|---------------|
| system_server | ActivityManagerService (AMS) | Lock contention, process lookup |
| system_server | PackageManagerService (PMS) | Package resolution, permission checks |
| system_server | WindowManagerService (WMS) | Window state transitions |
| surfaceflinger | SurfaceComposer | Buffer management, layer updates |
| mediaserver | MediaCodec/AudioFlinger | Codec allocation, audio routing |

## Trace Signatures

| What to Look For | Meaning |
|-----------------|---------|
| `binder transaction` slice on client thread | Client-side blocking duration |
| `binder reply` slice on server thread | Server-side execution time |
| blocked_function = `binder_wait_for_work` | Thread idle waiting for incoming binder work |
| `android_binder_client_server_breakdown` | Detailed server-side blame breakdown |

Server-side blame reasons from `android_binder_client_server_breakdown`:
- **monitor_contention** -- server thread waiting on a Java monitor lock
- **io** -- server performing disk or network I/O while handling the call
- **memory_reclaim** -- kernel reclaiming memory during the call
- **art_lock_contention** -- ART runtime internal lock contention

## Typical Solutions

- Switch to async binder (`oneway`) where result is not needed immediately
- Batch multiple IPC calls into a single transaction
- Defer non-critical IPC to a background thread
- Cache results of frequent queries (e.g., PackageManager info)
- Use `ContentResolver.query()` with a projection to minimize data transfer
- Pre-fetch data during idle time rather than on-demand during frame rendering
