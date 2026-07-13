GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/linux.strategy.md
Source SHA-256: 7ebec582b4f341fc6da19db3162aa28477be10a29a0720610361f1323508c8f5
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

# Linux Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

## Portable strategy metadata

```yaml
scene: linux
priority: 7
effort: medium
required_capabilities:
- cpu_scheduling
optional_capabilities:
- cpu_freq_idle
- perf_samples
keywords:
- linux
- kernel
- sched
- runqueue
- runnable
- pmu
- perf
- cache miss
- branch miss
- rss
- swap
- 内核
- 调度
- 调度延迟
- 缓存未命中
- 分支预测
compound_patterns:
- (linux|kernel|内核).*(调度|runqueue|PMU|perf|内存)
- (sched|runqueue|pmu|perf).*(latency|counter|miss|压力)
phase_hints:
- id: sched_latency
  keywords:
  - sched
  - runnable
  - runqueue
  - 调度
  - 延迟
  - 等待
  constraints: 调度问题优先调用 linux_sched_latency_distribution 和 linux_runqueue_depth_timeline；如果用户给定时间窗必须传 start_ts/end_ts。
  critical_tools:
  - linux_sched_latency_distribution
  - linux_runqueue_depth_timeline
  critical: true
- id: pmu_perf
  keywords:
  - PMU
  - perf
  - cache miss
  - branch miss
  - 缓存未命中
  - 分支预测
  constraints: PMU 问题调用 linux_perf_counter_hotspots。无 perf sample/counter 数据时必须说明 trace 未启用 PMU，不能给 cache/branch 结论。
  critical_tools:
  - linux_perf_counter_hotspots
  critical: false
- id: linux_memory
  keywords:
  - RSS
  - swap
  - 内存
  - resident
  - process memory
  constraints: Linux 进程内存问题调用 linux_process_rss_swap_timeline；page fault/reclaim 仍用 page_fault_in_range 做窗口级阻塞证据。
  critical_tools:
  - linux_process_rss_swap_timeline
  - page_fault_in_range
  critical: false
plan_template:
  mandatory_aspects:
  - id: sched_or_linux_signal
    match_keywords:
    - linux_sched_latency_distribution
    - linux_runqueue_depth_timeline
    - sched
    - runqueue
    - 调度
    suggestion: Linux 调度问题需要包含 sched latency 或 runqueue 深度分析
    required_expected_call_alternatives:
    - skill_id: linux_sched_latency_distribution
    - skill_id: linux_runqueue_depth_timeline
```

#### linux Core Strategy

**Route card**: linux / kernel / sched / runqueue / runnable / pmu / perf / cache miss / branch miss / rss

**Capabilities**: required=[cpu_scheduling], optional=[cpu_freq_idle, perf_samples]

**Phase reminders**
- sched_latency: 调度问题优先调用 linux_sched_latency_distribution 和 linux_runqueue_depth_timeline；如果用户给定时间窗必须传 start_ts/end_ts。 工具: linux_sched_latency_distribution, linux_runqueue_depth_timeline
- pmu_perf: PMU 问题调用 linux_perf_counter_hotspots。无 perf sample/counter 数据时必须说明 trace 未启用 PMU，不能给 cache/branch 结论。 工具: linux_perf_counter_hotspots
- linux_memory: Linux 进程内存问题调用 linux_process_rss_swap_timeline；page fault/reclaim 仍用 page_fault_in_range 做窗口级阻塞证据。 工具: linux_process_rss_swap_timeline, page_fault_in_range

**Final report contract summary**
- 遵循通用输出契约。


<!-- strategy-detail id="full" title="linux full strategy detail" keywords="linux,linux,kernel,sched,runqueue,runnable,pmu,perf,cache miss,branch miss,rss,swap,内核,Linux 内核 / 调度 / PMU 分析,detail,full" default="true" -->
#### Linux 内核 / 调度 / PMU 分析

Linux 场景必须先判断 trace 是否包含对应数据源：sched 基础数据通常存在，PMU/perf counter 需要额外 trace_config，RSS/swap 需要内存 counters。

**Phase 1 — 调度延迟与 runqueue：**


用于判断 Runnable→Running 等待是否构成瓶颈，以及系统级 runnable thread count 是否持续高压。

**Phase 2 — PMU / perf counter（仅数据可用时）：**


无 perf samples/counters 时，结论必须是"当前 trace 不支持 PMU 判断"。

**Phase 3 — 进程内存 / page fault：**


RSS/swap 是容量证据，page fault/reclaim 是阻塞证据，不能互相替代。
<!-- /strategy-detail -->
