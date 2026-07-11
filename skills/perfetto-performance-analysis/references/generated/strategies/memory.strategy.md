GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/memory.strategy.md
Source SHA-256: d38fac137bb6b82c262a19a8090b6648c5b8adede66969c4485a020a268540ac
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

# Memory Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

#### memory Core Strategy

**Route card**: 内存 / memory / oom / 泄漏 / leak / lmk / 内存压力 / 内存不足 / low memory / out of memory

**Capabilities**: required=[gc_memory, memory_pressure], optional=[cpu_scheduling, binder_ipc, battery_counters]





**Phase reminders**
- memory_evidence_gate: 先确认 memory_analysis/lmk/GC/heap graph/dmabuf 等证据哪些存在。结论必须按证据类型分层；缺失 Native/SO/匿名 mmap/thread stack/ApplicationExitInfo/MemoryLimiter 等来源时只写数据缺口，不能当成已证明。 工具: memory_analysis
- lmk_freezer_oom_boundary: LMK、freezer、Java OOM、Native OOM、Android 17 MemoryLimiter 是不同机制。只有对应事件、ApplicationExitInfo 或进程状态证据存在时才能命名；否则写成候选或采集建议。 工具: lmk_analysis, lmk_kill_attribution, oom_adjuster_score_timeline
- gc_churn_boundary: GC 与卡顿/ANR 重叠只能说明相关性。必须结合 GC pause、allocation churn、线程状态或帧/ANR窗口证据，避免把后台 GC 或普通回收直接写成根因。 工具: memory_analysis, gc_analysis
- memory_diagnostic_api_boundary: ApplicationExitInfo、ProfilingManager/ProfilingTrigger、heap dump/profile、KOOM/APM 都是补充证据。必须说明 API/Android 版本、record/artifact 时间、进程身份、reason/result file、与当前 trace 的对齐关系；不得把高内存直接等同泄漏，也不得把缺少退出记录写成没有 OOM/LMK。 工具: memory_analysis, lmk_analysis, lookup_knowledge

**Final report contract summary**
- 内存证据范围
- 内存类型拆分
- 置信度与缺失证据
- 内存诊断 API/剖析产物边界


**Detail ref**
- `memory:full`: 内存分析（用户提到 内存、memory、OOM、泄漏、LMK） 的完整 phase recipe、SQL、fetch_artifact 表、决策树和边界说明。


<!-- strategy-detail id="full" title="memory full strategy detail" keywords="memory,内存,memory,oom,泄漏,leak,lmk,内存压力,内存不足,low memory,out of memory,dmabuf,内存占用,内存分析（用户提到 内存、memory、OOM、泄漏、LMK）,detail,full" default="true" -->
#### 内存分析（用户提到 内存、memory、OOM、泄漏、LMK）

**核心原则：**
1. **先分证据源**：PSS/RSS、Java Heap、Native Heap、Graphics/dma-buf、GC、LMK/freezer、heap graph、ApplicationExitInfo/MemoryLimiter 等是不同口径。
2. **高内存不是泄漏**：必须先判断趋势、对象/类型归属、GC 后是否回落、缓存策略和进程角色，不能只凭峰值下结论。
3. **LMK/freezer/OOM 不能混用**：LMK 是系统低内存杀进程，freezer 是 cached process 冻结机制，Java/Native OOM 是进程内分配失败，MemoryLimiter 是版本敏感的系统退出原因。
4. **外部诊断是补充证据**：ApplicationExitInfo、ProfilingManager/ProfilingTrigger 产物、线上 OOM/KOOM、heap dump、APM 指标可以补上下文，但必须标明来源、版本/API 边界、record/artifact 时间、进程身份和与当前 trace 的对应关系。需要机制背景时调用 `lookup_knowledge("observability-diagnostics")`。
5. **缺失证据要进入结论**：trace 没有 heap graph、dmabuf、smaps、ApplicationExitInfo 或长窗口趋势时，只能输出候选和下一步采集建议。
6. **Heap Graph 泄漏只按证据分级**：`reachable=1` 只能说明 sample 时仍可达；只有可达对象与 sample 前生命周期（如 `onDestroy` / `onDestroyView`）对齐时，才能写成高置信泄漏候选。同类 Activity/Fragment 多实例只能写低置信候选，即使最近生命周期是 active/inactive，也不能升级成已泄漏。
7. **引用链从候选对象出发**：查 reference holder 时先收敛到 suspect object ids，再用 `heap_graph_reference.owned_id` 找持有者；引用来源需排除 Perfetto `_excluded_refs` 覆盖的 weak/phantom/finalizer referent 边；v56 的 `_excluded_refs` 不再排除 soft reference，不要自行把 soft referent 当作已过滤边，也不要对 heap graph 全量对象/引用做宽 JOIN 后直接下结论。
8. **RSS/Anon/Swap 是趋势辅证**：RSS 增长、单点跳跃、Peak/Avg 异常、Anon+Swap 占比能说明内存压力或增长形态，但不能单独证明 Java 泄漏或 PSS 问题。
9. **Profiler 只能回答各自能看见的问题**：Memory counters/LMK 给系统和进程趋势，ART heap dump 给 Java/Kotlin 引用保留图但不给分配调用栈，heapprofd 给 native malloc/free 族调用栈和观测窗口内分配/释放，不能把其中一个证据源升级成全量内存真相。
10. **采集窗口是结论边界**：heapprofd 不是 retroactive，只能看到 profiler 启动后的分配；Java heap dump 是 sample 点引用图；process stats 轮询可能漏掉很短的 RSS 峰值，`rss_stat`/`mm_event`/LMK 事件更适合捕获短时压力。缺失这些证据时必须转成具体采集建议。

**Perfetto 官方内存证据映射：**

| 问题 | 优先证据 | 能证明什么 | 不能证明什么 / 下一步 |
|------|----------|------------|------------------------|
| 当前进程为什么大 | `dumpsys meminfo`、`memory_rss_and_swap_per_process`、`memory_rss_high_watermark_per_process`、smaps | RSS/Swap/Anon/File/Watermark 趋势和大类占用 | 不能直接证明泄漏；需要 heap graph、heapprofd、dmabuf 或 smaps/mmap 归因 |
| 几毫秒级内存尖峰 | `linux.ftrace` 的 `kmem/rss_stat`、`mm_event/mm_event_record`、LMK 事件 | 轮询 counters 可能漏掉的短时 RSS burst、reclaim/compaction/fault 压力 | 如果只有 1s process stats，峰值结论必须降级 |
| Java/Kotlin 泄漏 | `android.java_hprof` / `heap_graph_*` / `android_heap_graph_class_summary_tree` | sample 点 reachable 对象、引用路径、dominator/retained size | 不含对象数据；不提供 allocation callstack；需要生命周期对齐才能写高置信泄漏 |
| Java OOMError | Android 14+ `android.java_hprof.oom` 触发 heap dump、ApplicationExitInfo | OOM 发生时 Java heap 引用图和进程退出上下文 | Java OOM 不等于系统 LMK，也不等于 native/device 内存耗尽 |
| Native 泄漏或 churn | `android.heapprofd` / `android_heap_profile_summary_tree` / `heap_profile_allocation` | profiler 启动后的 native 未释放保留、累计分配 churn、调用栈热点 | 不覆盖启动前已有分配；custom allocator/fragmentation/RSS 差异需要 meminfo/smaps/allocator 证据 |
| 系统低内存杀进程 | `mem.lmk`、`oom_score_adj`、process state | 被杀进程、adj/state、用户影响等级、kill storm | Android LMK 与 Linux OOM killer 机制不同；没有事件时不能命名 LMK |

#### 内存场景关键 Stdlib 表

写 execute_sql 时优先使用（完整列表见方法论模板）：`android_garbage_collection_events`、`android_oom_adj_intervals`、`android_screen_state`







**Phase 3 — 深度分析（按需选择）：**



**Phase 4 — 交叉分析：**
- 内存压力 + LMK → 检查是否有进程被反复杀死重启（thrashing）
- GC 频繁 + RSS/Anon 增长 → 可能存在分配抖动或 Java 对象增长，但需要 heap graph / allocation / GC 后回落证据确认
- Heap graph 可用 + retained class 集中 → 按 `android_heap_graph_summary` 的 top retainer 继续查 dominator/reference path；不要只按 raw object id 下结论
- Heap graph 可用 + destroyed Activity/Fragment 仍 reachable → 用 `android_heap_graph_leak_candidates` 输出高置信候选；没有生命周期对齐时只写候选，不写已泄漏
- Heapprofd 可用 + `native_signal=unreleased_native_retention` → 写 native 未释放保留候选；若 `native_signal=allocation_churn`，写分配抖动/allocator hotspot，不写泄漏；若 `retention_with_churn`，同时报告未释放保留和高分配 churn，不要把二者合并成单一根因
- DMA-BUF 增长 → GPU 内存泄漏（纹理/Buffer 未释放）
- 内存压力 + ANR → 系统内存不足导致的 ANR（非 App 代码 Bug）

**输出结构：**

1. **证据范围**：列出当前可用证据（PSS/RSS、Java Heap、Native Heap、Graphics/dma-buf、GC、LMK/freezer、heap graph、外部 API）和缺失证据
2. **内存概览**：总内存、已用内存、可用内存、趋势（增长/稳定/下降）
3. **内存类型拆分**：Java Heap / Native Heap / Graphics-dma-buf / RSS-PSS / mmap-SO / thread stack 中哪些有证据，哪些不可见
4. **Heap Graph 泄漏候选**（如有）：sample 时间、class、reachable 实例数、生命周期状态、引用持有者、置信度；没有 heap graph 时明确写缺失
5. **LMK/freezer/OOM 事件**（如有）：被杀/冻结/退出次数、受影响进程、OOM-adj 或 ApplicationExitInfo 来源；没有直接事件时不能命名
6. **诊断 API/剖析产物边界**（如用户提供或询问）：ApplicationExitInfo / ProfilingManager / ProfilingTrigger / heap dump / KOOM / APM 的 API level、reason/result file、record/artifact 时间、进程身份、与 trace 窗口的对齐关系，以及缺失证据
7. **根因分析**：泄漏、分配突增、缓存、GC churn、图形/Native 占用、系统压力之间的证据边界和置信度
8. **采集缺口**：按缺失证据给出下一次 trace 配置建议，例如 `linux.process_stats` 更短轮询、`kmem/rss_stat`、`mm_event/mm_event_record`、`lowmemorykiller/lowmemory_kill`、`oom/oom_score_adj_update`、`android.heapprofd`、`android.java_hprof`、`android.java_hprof.oom`、smaps/dmabuf
9. **优化建议**：按内存类型和证据强度分类；把缺失证据转化为具体采集建议
<!-- /strategy-detail -->
