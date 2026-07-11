GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/linux.strategy.md
Source SHA-256: 7ebec582b4f341fc6da19db3162aa28477be10a29a0720610361f1323508c8f5
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Linux Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

#### linux Core Strategy

**Route card**: linux / kernel / sched / runqueue / runnable / pmu / perf / cache miss / branch miss / rss

**Capabilities**: required=[cpu_scheduling], optional=[cpu_freq_idle, perf_samples]





**Phase reminders**
- sched_latency: 调度问题优先调用 linux_sched_latency_distribution 和 linux_runqueue_depth_timeline；如果用户给定时间窗必须传 start_ts/end_ts。 工具: linux_sched_latency_distribution, linux_runqueue_depth_timeline
- pmu_perf: PMU 问题调用 linux_perf_counter_hotspots。无 perf sample/counter 数据时必须说明 trace 未启用 PMU，不能给 cache/branch 结论。 工具: linux_perf_counter_hotspots
- linux_memory: Linux 进程内存问题调用 linux_process_rss_swap_timeline；page fault/reclaim 仍用 page_fault_in_range 做窗口级阻塞证据。 工具: linux_process_rss_swap_timeline, page_fault_in_range

**Final report contract summary**
- 遵循通用输出契约。


**Detail ref**
- `linux:full`: Linux 内核 / 调度 / PMU 分析 的完整 phase recipe、SQL、fetch_artifact 表、决策树和边界说明。


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
