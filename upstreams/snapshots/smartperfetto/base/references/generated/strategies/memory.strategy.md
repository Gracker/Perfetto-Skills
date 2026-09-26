GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/memory.strategy.md
Source SHA-256: f5a9a812f223b0db19cab510c3fc64ccbb2236a1a0a442efd5f745e5e028f722
Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

# Memory Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

`invoke_skill("<name>", {...})` steps mean: run `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill <name> --output-dir DIR` and pass each object field as `--param NAME=JSON`. Every Skill named this way is an exported, executable portable Skill, and every field is one of its declared inputs.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

## Portable strategy metadata

```yaml
scene: memory
classification_description: Memory usage, allocation, garbage collection, pressure, leaks and memory-related process termination.
priority: 4
effort: medium
required_capabilities:
- gc_memory
- memory_pressure
optional_capabilities:
- cpu_scheduling
- binder_ipc
- battery_counters
keywords:
- 内存
- memory
- oom
- 泄漏
- leak
- lmk
- 内存压力
- 内存不足
- low memory
- out of memory
- dmabuf
- 内存占用
final_report_contract:
  required_sections:
  - id: memory_evidence_scope
    label: 内存证据范围
    description: 说明当前结论基于哪些内存证据源，并列出缺失或不可证明的证据。
    pattern_groups:
    - - 证据范围
      - 证据来源
      - 数据来源
      - evidence\s+scope
      - evidence\s+source
    - - PSS
      - RSS
      - Java\s+Heap
      - Native\s+Heap
      - Graphics
      - dma[-_ ]?buf
      - GC
      - LMK
      - heap\s+graph
      - 缺失
      - missing
  - id: memory_type_breakdown
    label: 内存类型拆分
    description: 把 Java、Native、Graphics/dma-buf、RSS/PSS、GC、LMK/freezer 等口径分开。
    pattern_groups:
    - - 内存类型
      - 类型拆分
      - 分类
      - breakdown
      - Java\s+Heap
      - Native\s+Heap
      - Graphics
      - dma[-_ ]?buf
    - - 泄漏
      - leak
      - 增长
      - churn
      - 分配
      - 回收
      - GC
      - LMK
      - freezer
      - OOM
      - 压力
      - pressure
  - id: memory_confidence_boundary
    label: 置信度与缺失证据
    description: 明确高内存、泄漏、GC、LMK/freezer/OOM、外部诊断 API 之间的证据边界。
    pattern_groups:
    - - 证据不足
      - 缺失
      - missing
      - limitation
      - 限制
      - 置信
      - confidence
      - 需补
      - 建议采集
    - - 不等于
      - 不能
      - 不得
      - 区分
      - 边界
      - separate
      - not
  - id: memory_diagnostic_api_boundary
    label: 内存诊断 API/剖析产物边界
    description: 当用户主动提到 ApplicationExitInfo、ProfilingManager、ProfilingTrigger、heap dump/profile、KOOM 或 APM 时，区分当前 trace 内存证据、退出记录、剖析产物、外部聚合和缺失证据。
    condition:
      kind: semantic
      description: 当问题要求使用进程退出记录、堆转储或剖析结果、内存监控平台等外部诊断材料解释内存现象时适用。
    pattern_groups:
    - - 内存诊断 API/剖析产物边界
      - memory diagnostic API
      - profiling artifact
      - ApplicationExitInfo
      - ProfilingManager
      - ProfilingTrigger
      - heap dump
      - heap profile
    - - diagnostic_api
      - profiling_artifact
      - external_aggregate
      - ApplicationExitInfo
      - getHistoricalProcessExitReasons
      - REASON_LOW_MEMORY
      - REASON_FREEZER
      - REASON_EXCESSIVE_RESOURCE_USAGE
      - ProfilingManager
      - ProfilingTrigger
      - KOOM
      - APM
    - - API\s*3[0567]
      - Android\s*1[1567]
      - version
      - 版本
      - reason
      - process
      - pid
      - upid
      - timestamp
      - result file
      - artifact
      - record
    - - trace window
      - current trace
      - align
      - 对齐
      - missing
      - 缺失
      - confidence
      - 置信
      - 不能
      - 不可
      - not prove
      - not equal
phase_hints:
- id: memory_evidence_gate
  keywords:
  - memory
  - 内存
  - heap
  - rss
  - pss
  - gc
  - lmk
  - memory_analysis
  - 证据
  constraints: 先确认 memory_analysis/lmk/GC/heap graph/dmabuf 等证据哪些存在。结论必须按证据类型分层；缺失 Native/SO/匿名 mmap/thread stack/ApplicationExitInfo/MemoryLimiter
    等来源时只写数据缺口，不能当成已证明。
  critical_tools:
  - memory_analysis
  critical: true
- id: lmk_freezer_oom_boundary
  keywords:
  - lmk
  - oom
  - freezer
  - kill
  - 杀进程
  - 低内存
  - 内存压力
  constraints: LMK、freezer、Java OOM、Native OOM、Android 17 MemoryLimiter 是不同机制。只有对应事件、ApplicationExitInfo 或进程状态证据存在时才能命名；否则写成候选或采集建议。
  critical_tools:
  - lmk_analysis
  - lmk_kill_attribution
  - oom_adjuster_score_timeline
  critical: false
- id: gc_churn_boundary
  keywords:
  - gc
  - churn
  - allocation
  - 分配
  - 回收
  - 抖动
  - pause
  constraints: GC 与卡顿/ANR 重叠只能说明相关性。必须结合 GC pause、allocation churn、线程状态或帧/ANR窗口证据，避免把后台 GC 或普通回收直接写成根因。
  critical_tools:
  - memory_analysis
  - gc_analysis
  critical: false
- id: memory_diagnostic_api_boundary
  keywords:
  - ApplicationExitInfo
  - getHistoricalProcessExitReasons
  - REASON_LOW_MEMORY
  - REASON_FREEZER
  - REASON_EXCESSIVE_RESOURCE_USAGE
  - ProfilingManager
  - ProfilingTrigger
  - heap dump
  - heap profile
  - KOOM
  - APM
  constraints: ApplicationExitInfo、ProfilingManager/ProfilingTrigger、heap dump/profile、KOOM/APM 都是补充证据。必须说明 API/Android 版本、record/artifact
    时间、进程身份、reason/result file、与当前 trace 的对齐关系；不得把高内存直接等同泄漏，也不得把缺少退出记录写成没有 OOM/LMK。
  critical_tools:
  - memory_analysis
  - lmk_analysis
  critical: false
plan_template:
  mandatory_aspects:
  - id: memory_trend_and_gc
    match_keywords:
    - memory
    - oom
    - gc
    - 内存
    - heap
    - lmk
    - memory_analysis
    suggestion: 内存场景建议包含内存使用趋势和 GC 分析阶段 (memory_analysis)
    required_expected_calls:
    - skill_id: memory_analysis
```

## Investigation methodology

Apply `system_execution` version 1 from [shared investigation methods](investigation-profiles.yaml.md).

Apply `causal_reasoning` version 1 from [shared investigation methods](investigation-profiles.yaml.md).

### memory_critical_path (critical_path)

Select allocation, GC, reclaim, page-fault or LMK windows and their actual tasks. Relate observed memory pressure and task states; use CPU frequency only where execution slowdown is relevant.

### memory_dependencies (dependency_chain)

Keep memory growth, leakage, OOM/LMK, reclaim and GC evidence distinct. A high allocation count or concurrent pressure alone does not establish a latency or failure cause.

#### memory Core Strategy

**Route card**: 内存 / memory / oom / 泄漏 / leak / lmk / 内存压力 / 内存不足 / low memory / out of memory

**Capabilities**: required=[gc_memory, memory_pressure], optional=[cpu_scheduling, binder_ipc, battery_counters]

**Mandatory aspects**
- memory_trend_and_gc: 内存场景建议包含内存使用趋势和 GC 分析阶段 (memory_analysis) (required: invoke_skill(memory_analysis))

**Final report contract summary**
- 内存证据范围
- 内存类型拆分
- 置信度与缺失证据
- 内存诊断 API/剖析产物边界


<!-- strategy-detail id="full" title="memory full strategy detail" keywords="memory,内存,memory,oom,泄漏,leak,lmk,内存压力,内存不足,low memory,out of memory,dmabuf,内存占用,内存分析（用户提到 内存、memory、OOM、泄漏、LMK）,detail,full" default="true" -->
#### 内存分析（用户提到 内存、memory、OOM、泄漏、LMK）

**Perfetto 官方内存证据映射：**

| 问题 | 优先证据 | 能证明什么 | 不能证明什么 / 下一步 |
|------|----------|------------|------------------------|
| 当前进程为什么大 | `dumpsys meminfo`、`memory_rss_and_swap_per_process`、`memory_rss_high_watermark_per_process`、smaps | RSS/Swap/Anon/File/Watermark 趋势和大类占用 | 不能直接证明泄漏；需要 heap graph、heapprofd、dmabuf 或 smaps/mmap 归因 |
| 几毫秒级内存尖峰 | `linux.ftrace` 的 `kmem/rss_stat`、`mm_event/mm_event_record`、LMK 事件 | 轮询 counters 可能漏掉的短时 RSS burst、reclaim/compaction/fault 压力 | 如果只有 1s process stats，峰值结论必须降级 |
| Java/Kotlin 泄漏 | `android.java_hprof` / `heap_graph_*` / `android_heap_graph_class_summary_tree` | sample 点 reachable 对象、引用路径、dominator/retained size | 不含对象数据；不提供 allocation callstack；需要生命周期对齐才能写高置信泄漏 |
| Java OOMError | Android 14+ `android.java_hprof.oom` 触发 heap dump、ApplicationExitInfo | OOM 发生时 Java heap 引用图和进程退出上下文 | Java OOM 不等于系统 LMK，也不等于 native/device 内存耗尽 |
| Native 泄漏或 churn | `android.heapprofd` `libc.malloc` / `native_heap_breakdown` | profiler 启动后按进程的 native 未释放保留、累计分配 churn、分配器之上首个应用/库帧 | 不覆盖启动前已有分配；custom allocator/fragmentation/RSS 差异需要 meminfo/smaps/allocator 证据 |
| Java 分配 churn | heapprofd `com.android.art` / `native_heap_breakdown` | 分配字节/次数和分配调用栈（GC 压力来源） | 不记录释放，不能证明 Java 保留或泄漏；需要 heap dump |
| 系统低内存杀进程 | `mem.lmk`、`oom_score_adj`、process state | 被杀进程、adj/state、用户影响等级、kill storm | Android LMK 与 Linux OOM killer 机制不同；没有事件时不能命名 LMK |

#### 内存场景关键 Stdlib 表

写 execute_sql 时优先使用（完整列表见方法论模板）：`android_garbage_collection_events`、`android_oom_adj_intervals`、`android_screen_state`

**Phase 1 — 内存概览（1 次调用）：**
```
invoke_skill("memory_analysis")
```
返回：内存使用趋势、RSS/PSS 分布、内存分类统计。

**Phase 2 — LMK 分析（如果有 LMK 事件）：**
```
invoke_skill("lmk_analysis")
```
返回：LMK 事件列表、被杀进程、OOM-adj 分布、重启循环检测。

如果需要更轻量的事件/分数视图，或 `lmk_analysis` 结果为空但用户明确问 OOM/adj：
```
invoke_skill("lmk_kill_attribution")
invoke_skill("oom_adjuster_score_timeline")
invoke_skill("memory_rss_high_watermark")
```
- `lmk_kill_attribution`：LMK 事件、被杀进程、adj、oom_score_adj
- `oom_adjuster_score_timeline`：进程 OOM adj 分数时间线
- `memory_rss_high_watermark`：RSS high watermark，辅助识别增长型内存压力

需要解释进程为什么被杀、在后台停留多久，或 adj 变化背后的 framework 角色时：
```
invoke_skill("android_process_state_residency", { process_name })
```
- `process_state_residency`：各 framework 进程状态（TOP、FOREGROUND_SERVICE、CACHED_* 等）在存活时间内的驻留时长和占比
- `process_state_transitions`：状态切换序列、上一状态停留时长、OomAdjuster 原因
- `process_state_last_observed`：每个进程最后一次观测到的状态；进程已结束时就是它结束前所处的状态
- `oom_score_adj` 是内核看到的分数，process state 是 framework 给的角色，两者对照着读：长时间 CACHED_* 解释了为什么在内存压力下先被杀；被杀前处于 TOP/FOREGROUND_SERVICE 则说明是压力极高或异常 kill，不是正常的缓存回收
- `process_state_capability.status=runtime_lacks_process_state` 表示 trace processor 早于该解析器，`no_process_state_data` 表示采集没开 `android.process_state` 或设备不支持；两种都只能写数据缺口，不能写“进程一直在前台”

**Phase 3 — 深度分析（按需选择）：**

**Phase 4 — 交叉分析：**
- 内存压力 + LMK → 检查是否有进程被反复杀死重启（thrashing）
- LMK 事件 + process state 可用 → 用 `process_state_last_observed` 和 `process_state_residency` 说明被杀进程当时的 framework 角色和在 CACHED 状态停留的时间，再与 kill 的 adj 对照；两者不一致时如实报告，不强行统一
- GC 频繁 + RSS/Anon 增长 → 可能存在分配抖动或 Java 对象增长，但需要 heap graph / allocation / GC 后回落证据确认
- Heap graph 可用 + retained class 集中 → 按 `android_heap_graph_summary` 的 top retainer 继续查 dominator/reference path；不要只按 raw object id 下结论
- Heap dump class 增长 `growth_signal=instance_growth` → 报告首次→末次实例数（如 2 → 6，+4）和 dominated 增量，再对该 class 查 dominator/reference path；`retained_growth_only` 是实例数不变但保留集变大的持有者，通常是引用链上的容器，不是泄漏对象本身；`monotonic_growth=0` 说明中间有回落，写成波动而非持续增长；`comparability=incomplete_dump_lower_bound` 时增量只是下界
- Heap graph 可用 + destroyed Activity/Fragment 仍 reachable → 用 `android_heap_graph_leak_candidates` 输出高置信候选；没有生命周期对齐时只写候选，不写已泄漏
- Heapprofd 可用 + `native_signal=unreleased_native_retention` → 写 native 未释放保留候选；若 `native_signal=allocation_churn`，写分配抖动/allocator hotspot，不写泄漏；若 `retention_with_churn`，同时报告未释放保留和高分配 churn，不要把二者合并成单一根因
- Heap `com.android.art`（`retention_claim=churn_only_frees_not_recorded`）→ 只报分配字节/次数和热点，不写 Java 泄漏；两次 profile 的差值在一个采样间隔（默认 4096 B）内视为噪声；`heapprofd_issues` 非 none 时说明 profile 可能截断
- Heap dump `dump_completeness=incomplete_dump`（self_size=-1 占位对象、丢包统计或 `heap_graph.truncated`）→ 大小和实例数只是下界，不能据此写“没有泄漏”；`process_identity=process_name_unavailable_upid_fallback`（如 .hprof 无进程名）→ 用 upid + graph_sample_ts 指代并说明进程身份未知
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
