GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/io.strategy.md
Source SHA-256: caa9981eaec7ac91adbedcaacbe12d693bfc4d5694f8c3ede42483b74c3ecc6e
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

# Io Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

#### io Core Strategy

**Route card**: io / i/o / disk / storage / filesystem / block io / fsync / fdatasync / page fault / sqlite

**Capabilities**: required=[none], optional=[disk_io, binder_ipc, cpu_scheduling]





**Phase reminders**
- io_evidence_ladder: 先区分 block I/O、D-state 等待、主线程文件 I/O、page fault、容量/损坏/外部存储线索。缺少路径、线程、栈或 block 层证据时只能写数据缺口，不能把系统 I/O 压力直接升级为业务根因。 工具: block_io_analysis, io_pressure, main_thread_file_io_in_range, page_fault_in_range
- sqlite_sharedprefs_provider_boundary: SQLite/Room、SharedPreferences/QueuedWork、ContentProvider/CursorWindow/MediaProvider 是不同证明路径。必须有 slice/stack/Binder/provider-side evidence 才能命名；只有 D-state/fsync 时写成候选和补证建议。 工具: blocking_chain_analysis, main_thread_file_io_in_range, binder_analysis

**Final report contract summary**
- I/O 证据类型
- 文件/数据库/Provider 边界
- 置信度与补证





<!-- strategy-detail id="full" title="io full strategy detail" keywords="io,io,i/o,disk,storage,filesystem,block io,fsync,fdatasync,page fault,sqlite,sqliteopenhelper,room,I/O / Storage / SQLite 分析,detail,full" default="true" -->
#### I/O / Storage / SQLite 分析

I/O 场景的第一原则：先分证据类型，再命名根因。`D-state`、`fsync`、`page fault`、block layer 延迟、主线程文件 I/O、SQLite/Room、SharedPreferences/QueuedWork、ContentProvider/MediaProvider 是不同证据路径。

不要把单一 `D-state` 或 `fsync` 直接写成“SQLite 根因”。`D-state` 只是不可中断等待；只有 `io_wait=1` 或 IO/page-cache `blocked_function` 才能升级为 I/O 候选，最终仍需 SQLite/Room/SQLiteOpenHelper、connection wait、WAL/checkpoint、CursorWindow、Room migration/open、provider-side DB work、或相关 Java/native stack/slice/Binder evidence 才能命名为数据库或 Provider 根因。

报告 `D-state`、`io_wait` 或 `blocked_function` 时，调用 `lookup_knowledge("thread-state-blocked-reason")` 解释 kernel wchan 单帧、证据强度和下一步补证。

#### I/O 场景关键 Stdlib 表

优先使用现有 Skills 建立证据梯子；必要时再用 `execute_sql` 验证线程、slice、sched state 和 block I/O。

**Phase 1 — I/O 证据类型门禁：**



如果用户给出具体时间窗或主线程阻塞，需要补：



输出时先写清楚证据属于哪一类：
1. `block_io`: block 层请求排队、issue/complete 延迟、设备或文件系统压力。
2. `thread_wait`: 主线程或关键线程 `D-state`、blocked_functions、waker/blocked chain。
3. `file_api`: read/write/fsync/fdatasync、文件路径或路径类型。
4. `page_fault`: 文件映射首次访问、page cache miss、reclaim 后重新读。
5. `missing_evidence`: trace 没有路径、栈、block I/O 或 app API signal。

**Phase 2 — App API 边界：**

按证据把根因拆开：

| 类别 | 需要看到的证据 | 不能做的推断 |
|---|---|---|
| File I/O | read/write/fsync/fdatasync、路径、线程、耗时 | 不能只凭 D-state 断定业务文件读写 |
| SharedPreferences/QueuedWork | `SharedPreferencesImpl.awaitLoadedLocked`、`QueuedWork.waitToFinish`、XML rewrite/fsync、组件 lifecycle stop | `apply()` 返回快不代表没有 lifecycle wait；不能写成 apply 当前调用同步阻塞 |
| SQLite/Room | SQLite/Room/OpenHelper slice 或 stack、connection wait、long transaction、WAL/checkpoint、migration/open、query execution | 不能把任意 fsync 或 block I/O 写成 DB 根因 |
| ContentProvider/CursorWindow | caller proxy wait、provider Binder thread、provider-side DB/lock/cold-start、`CursorWindow` fill/refill | Binder 控制面和 CursorWindow 数据面要分开；不能只看 caller 线程 |
| MediaProvider/scoped storage | FUSE/passthrough、MediaProvider CPU/DB、权限/redaction/transcode、底层 block I/O | `/storage/emulated/0` 不等同普通文件路径 |

ContentProvider 相关问题必须区分 caller 侧等待、provider 侧 Binder 线程、provider 冷启动/锁/DB，以及 CursorWindow shared-memory 数据面。Provider CRUD 没有独立“provider ANR”类型，通常继承调用方的组件超时。

**Phase 3 — 交叉验证：**

- 启动慢 + fsync/D-state：回到 startup strategy，确认阶段、TTID/TTFD、startup_detail 和业务可改 slice。
- ANR + I/O：回到 anr strategy，确认 timeout source、主线程阻塞链、victim/root-cause process。
- SQLite/Room 候选：检查是否有 connection pool wait、长事务、migration/open、WAL/checkpoint、CursorWindow/refill；缺少这些时只写“数据库证据不足”。
- SharedPreferences 候选：检查首次加载、XML rewrite、QueuedWork lifecycle wait、文件大小/写频率；缺少 stack/slice 时只写候选。
- Scoped storage/MediaProvider 候选：检查路径类型、provider Binder/CPU/DB、FUSE/passthrough、权限/转码线索和底层 block I/O。

**输出结构：**

1. **I/O 证据类型**：block I/O / D-state / 主线程文件 I/O / SQLite-DB slice / page fault / external storage / missing evidence。
2. **文件/数据库/Provider 边界**：File I/O、SharedPreferences/QueuedWork、SQLite/Room、ContentProvider/CursorWindow/MediaProvider 分别有什么证据或缺口。
3. **阻塞链路**：caller thread、provider/server thread、block device、waker 或 lock owner。
4. **根因与置信度**：直接证据、候选、不可证明项分开写；不要把 D-state/fsync 自动升级为 DB 根因。
5. **下一步补证**：需要补采路径、Java/native stack、SQLite/Room trace、provider-side trace、block I/O、设备存储状态或 APM/IO Canary 证据。
<!-- /strategy-detail -->
