GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-data-sources.template.md
Source SHA-256: eb034d0e2cd592b9279a3efc87c6573d4ce857e2c928fd30ec2df7949d2e2556
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

# Knowledge Data Sources Template

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

# Trace 数据源与采集指南

当分析中发现某些数据不可用时，参考以下指南告知用户如何采集所需数据。

---

## 帧渲染与滑动分析 (frame_rendering)

**依赖表**: `actual_frame_timeline_slice`, `expected_frame_timeline_slice`
**架构适用**: STANDARD, COMPOSE, MIXED
**最低版本**: Android 12 (API 31) — Frame Timeline API

### 所需采集配置

**必要源:**
- atrace category: `gfx` — 图形渲染管线事件
- atrace category: `view` — View 系统 (measure/layout/draw)

**增强源:**
- atrace category: `input` — 关联输入延迟与帧超时
- ftrace event: `sched/sched_switch` — 分析渲染线程被抢占

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      atrace_categories: "gfx"
      atrace_categories: "view"
      atrace_categories: "input"
      ftrace_events: "sched/sched_switch"
    }
  }
}
```

### 常见缺失原因
- 未开启 `gfx` atrace category（最常见）
- Android 11 及以下版本不支持 Frame Timeline API — 降级为 Choreographer slice 分析
- Flutter/WebView 架构不走 Android Frame Timeline — 使用各自专用管线分析

---

## Flutter 滑动分析 (flutter_rendering)

**依赖表**: `slice`（含 Flutter 引擎 slice）
**架构适用**: FLUTTER
**最低版本**: Android 任意版本（依赖 Flutter SDK tracing）

### 所需采集配置

**必要源:**
- atrace category: `gfx` — SurfaceFlinger 合成
- Flutter SDK tracing（应用内启用 `debugProfileBuildsEnabled`）

**增强源:**
- atrace category: `view` — 混合 Flutter + Native 场景

### 常见缺失原因
- Flutter 应用未开启 performance overlay / tracing
- TextureView 模式下缺少 RenderThread 事件（正常 — 使用 Flutter 自己的 raster 线程）
- SurfaceView 模式下 1.ui/1.raster 线程 slice 缺失 — 检查 Flutter SDK 版本

---

## 启动性能分析 (startup)

**依赖表**: `android_startups`, `android_startup_opinionated_breakdown`
**架构适用**: 所有架构
**最低版本**: Android 10 (API 29) — Perfetto stdlib 需要 `android.startup` module

### 所需采集配置

**必要源:**
- atrace category: `am` — ActivityManager 启动事件
- atrace category: `dalvik` — ART 虚拟机事件（bindApplication, GC）
- atrace category: `wm` — WindowManager（窗口绘制完成时间点）

**增强源:**
- atrace category: `ss` — System Server（`system_server` 侧开销）
- atrace category: `binder_driver` — Binder 调用延迟
- ftrace event: `sched/sched_switch` — 启动期间线程调度
- ftrace event: `sched/sched_blocked_reason` — `thread_state.io_wait` 与 kernel single-frame `blocked_function` 诊断
- ftrace event: `filemap/mm_filemap_add_to_page_cache` — Page Cache miss 检测

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      atrace_categories: "am"
      atrace_categories: "dalvik"
      atrace_categories: "wm"
      atrace_categories: "ss"
      atrace_categories: "binder_driver"
      ftrace_events: "sched/sched_switch"
      ftrace_events: "sched/sched_wakeup"
      ftrace_events: "sched/sched_blocked_reason"
      ftrace_events: "filemap/mm_filemap_add_to_page_cache"
    }
  }
}
```

### 常见缺失原因
- 未开启 `am` category 导致 `android_startups` 表为空
- Trace 采集开始太晚，错过了启动事件（应在启动前开始采集）
- 第三方 ROM 的 ActivityManager atrace 标记不标准

---

## Binder/IPC 分析 (binder_ipc)

**依赖表**: `android_binder_txns`, `android_sync_binder_thread_state_by_txn`
**架构适用**: 所有架构
**最低版本**: Android 10 (API 29)

### 所需采集配置

**必要源:**
- atrace category: `binder_driver` — Binder 驱动事件
- ftrace event: `binder/binder_transaction` — 事务开始/结束

**增强源:**
- ftrace event: `binder/binder_lock` — Binder 锁竞争（已在 Android 12+ 移除）
- ftrace event: `sched/sched_switch` — 关联 Binder 阻塞期间的 CPU 调度

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      atrace_categories: "binder_driver"
      ftrace_events: "binder/binder_transaction"
      ftrace_events: "binder/binder_transaction_received"
    }
  }
}
```

### 常见缺失原因
- 未开启 `binder_driver` atrace category
- 某些厂商 ROM 禁用了 Binder tracing（安全限制）
- Trace buffer 过小导致 Binder 事件被覆盖（建议 buffer >= 32MB）

---

## 锁竞争分析 (lock_contention)

**依赖表**: `android_monitor_contention`, `android_monitor_contention_chain`
**架构适用**: 所有架构（仅 Java/Kotlin 代码）
**最低版本**: Android 13 (API 33) — ART monitor contention tracing

### 所需采集配置

**必要源:**
- ART monitor contention tracing — 通过 Perfetto 配置启用

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      atrace_categories: "dalvik"
      atrace_apps: "*"
    }
  }
}
```

> **注意**: Monitor contention 事件需要 Android 13+ 的 ART 支持。即使开启了 `dalvik` category，Android 12 及以下版本不会产出 `android_monitor_contention` 数据。

### 常见缺失原因
- Android 12 及以下版本不支持（版本限制，非配置问题）
- 未开启 `dalvik` atrace category
- 应用使用 Native 锁（pthread_mutex）而非 Java synchronized — 需要 `futex` ftrace 事件

---

## GC/内存分析 (gc_memory)

**依赖表**: `android_garbage_collection_events`
**架构适用**: 所有 Java/Kotlin 架构
**最低版本**: Android 10 (API 29)

### 所需采集配置

**必要源:**
- atrace category: `dalvik` — ART GC 事件

**增强源:**
- atrace category: `memory` — 系统级内存事件
- Perfetto data source: `android.heapprofd` — 堆内存 profiling（需要 root 或 debuggable 应用）

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      atrace_categories: "dalvik"
      atrace_categories: "memory"
    }
  }
}
```

### 常见缺失原因
- 未开启 `dalvik` category（与启动分析相同）
- Release 版本的 ART 可能省略部分 GC trace 标记

---

## 内存压力/LMK (memory_pressure)

**依赖表**: `android_lmk_events`, `android_oom_adj_intervals`, `android_process_memory_intervals`
**架构适用**: 所有架构
**最低版本**: Android 10 (API 29)

### 所需采集配置

**必要源:**
- ftrace event: `oom/oom_score_adj_update` — OOM adj 变化
- ftrace event: `lowmemorykiller/*` — LMK 事件（旧内核）
- Perfetto data source: `linux.process_stats` — 进程内存统计

**增强源:**
- ftrace event: `vmscan/*` — 内存回收事件
- Perfetto data source: `linux.sys_stats` — 系统级内存指标（MemFree/MemAvailable）

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      ftrace_events: "oom/oom_score_adj_update"
      ftrace_events: "lowmemorykiller/lowmemory_kill"
    }
  }
}
data_sources {
  config {
    name: "linux.process_stats"
    process_stats_config {
      proc_stats_poll_ms: 1000
    }
  }
}
```

### 常见缺失原因
- 未启用 `linux.process_stats` data source
- 新内核（5.10+）使用 `lmkd` 用户态而非内核 LMK — 需要不同的 ftrace 事件
- Trace 时长不够 — LMK 事件相对低频

---

## CPU 调度分析 (cpu_scheduling)

**依赖表**: `sched_slice`, `thread_state`
**架构适用**: 所有架构
**最低版本**: 任意版本（Linux 内核基础功能）

### 所需采集配置

**必要源:**
- ftrace event: `sched/sched_switch` — CPU 调度切换
- ftrace event: `sched/sched_wakeup` — 线程唤醒

**增强源:**
- ftrace event: `sched/sched_blocked_reason` — `thread_state.io_wait` 与 kernel single-frame `blocked_function` 诊断
- ftrace event: `power/cpu_frequency` — CPU 频率变化
- ftrace event: `power/cpu_idle` — CPU idle 状态

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      ftrace_events: "sched/sched_switch"
      ftrace_events: "sched/sched_wakeup"
      ftrace_events: "sched/sched_blocked_reason"
      ftrace_events: "power/cpu_frequency"
      ftrace_events: "power/cpu_idle"
      compact_sched {
        enabled: true
      }
    }
  }
}
```

### 常见缺失原因
- 这些是最基础的 ftrace 事件，大多数 Perfetto 配置默认包含
- 如果 `sched_slice` 为空，可能是 Trace 文件格式不兼容或 trace_processor 解析失败
- `sched_blocked_reason` 需要 trace config 显式采集该 ftrace event，且设备暴露该 tracepoint / kernel symbolization 可用；如果仍缺失，报告为 blocked_function 数据不可用，不要只归因 CONFIG_SCHEDSTATS
- 如果需要阻塞瞬间的完整 kernel/userspace off-CPU stack，另配 `linux.perf` 基于 `sched_switch` / `sched_waking` 的事件采样，并过滤目标线程，避免全系统 every-switch 采样过载

---

## 热降频分析 (thermal_throttling)

**依赖表**: `counter`（thermal_zone counters）, `android_dvfs_counters`
**架构适用**: 所有架构
**最低版本**: 任意版本

### 所需采集配置

**必要源:**
- ftrace event: `power/cpu_frequency` — CPU 频率变化（频率被钳位时可诊断降频）

**增强源:**
- ftrace event: `thermal/*` — 热区温度和功耗限制
- Perfetto data source: `linux.sys_stats` — 系统统计（包含 thermal zone）

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      ftrace_events: "power/cpu_frequency"
      ftrace_events: "thermal/thermal_temperature"
      ftrace_events: "thermal/cdev_update"
    }
  }
}
```

### 常见缺失原因
- `thermal/*` ftrace 事件依赖设备/内核支持，非所有设备都暴露
- 即使无 thermal ftrace，可通过 CPU 频率钳位间接诊断降频
- GPU 降频依赖厂商特定的 counter track（Qualcomm/MTK/Exynos 各不同）

---

## I/O 分析 (disk_io)

**依赖表**: `linux_active_block_io_operations_by_device`
**架构适用**: 所有架构
**最低版本**: 任意版本

### 所需采集配置

**必要源:**
- ftrace event: `block/block_rq_issue` — 磁盘 I/O 请求发起
- ftrace event: `block/block_rq_complete` — 磁盘 I/O 请求完成

**增强源:**
- ftrace event: `ext4/*` 或 `f2fs/*` — 文件系统级 I/O（依赖设备文件系统类型）

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      ftrace_events: "block/block_rq_issue"
      ftrace_events: "block/block_rq_complete"
    }
  }
}
```

### 常见缺失原因
- 未启用 `block` ftrace 事件
- 某些设备/内核版本的 block 事件格式不标准

---

## GPU 分析 (gpu)

**依赖表**: `gpu_slice`, `android_gpu_frequency`
**架构适用**: 所有架构
**最低版本**: Android 12 (API 31) — GPU work period API

### 所需采集配置

**必要源:**
- atrace category: `gpu` — GPU 工作周期事件

**增强源:**
- Perfetto data source: `gpu.counters` — GPU 性能计数器（依赖驱动支持）
- Perfetto data source: `gpu.renderstages` — GPU 渲染阶段（Vulkan only）

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      atrace_categories: "gpu"
    }
  }
}
data_sources {
  config {
    name: "gpu.counters"
  }
}
```

### 常见缺失原因
- GPU work period API 需要 Android 12+ 和驱动支持
- GPU counter 支持依赖 GPU 驱动（Adreno/Mali/PowerVR 各不同）
- 某些设备上 `gpu` atrace category 不产出任何事件

---

## CPU Profiling (cpu_profiling)

**依赖表**: `linux_perf_samples_summary_tree`, `cpu_profiling_summary_tree`
**架构适用**: 所有架构
**最低版本**: Android 10 (API 29)

### 所需采集配置

**必要源:**
- Perfetto data source: `linux.perf` — CPU 采样

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.perf"
    perf_event_config {
      timebase {
        frequency: 100
        counter: PERF_COUNT_SW_CPU_CLOCK
      }
      callstack_sampling {
        kernel_frames: true
      }
    }
  }
}
```

### 常见缺失原因
- `linux.perf` 需要单独配置，大多数默认 Perfetto 配置不包含
- 需要 root 或 `perf_harden=0`（`adb shell setprop security.perf_harden 0`）
- simpleperf 的数据可转换为 Perfetto 格式导入

---

## 输入延迟分析 (input_latency)

**依赖表**: `android_input_events`, `android_input_event_dispatch`
**架构适用**: 所有架构
**最低版本**: Android 14 (API 34) — Input tracing stdlib support

### 所需采集配置

**必要源:**
- atrace category: `input` — 输入事件管线
- Perfetto data source: `android.input.inputevent` — 详细输入事件（Android 14+）

**增强源:**
- atrace category: `wm` — 窗口焦点变化

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      atrace_categories: "input"
    }
  }
}
data_sources {
  config {
    name: "android.input.inputevent"
    android_input_event_config {
      mode: TRACE_MODE_TRACE_ALL
    }
  }
}
```

### 常见缺失原因
- `android_input_events` 表需要 Android 14+ 的 stdlib 支持
- Android 13 及以下版本可通过 `slice` 表中的 input dispatch slice 间接分析
- 输入事件可能因安全策略被过滤（隐私保护）

---

## SurfaceFlinger/Display 管线 (surfaceflinger)

**依赖表**: `android_surfaceflinger_workloads`, `android_surfaceflinger_transaction`
**架构适用**: 所有架构
**最低版本**: Android 12 (API 31)

### 所需采集配置

**必要源:**
- atrace category: `sf` — SurfaceFlinger 事件

**增强源:**
- Perfetto data source: `android.surfaceflinger.layers` — Layer 级别事件
- Perfetto data source: `android.surfaceflinger.transactions` — SF 事务详情

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      atrace_categories: "sf"
    }
  }
}
data_sources {
  config {
    name: "android.surfaceflinger.layers"
    surfaceflinger_layers_config {
      mode: MODE_ACTIVE
    }
  }
}
```

### 常见缺失原因
- 未开启 `sf` atrace category
- SF layers/transactions data source 需要单独配置
- 部分厂商 ROM 对 SF tracing 有限制

---

## 网络分析 (network)

**依赖表**: `slice`（含网络相关 slice）, `android_network_packets`（Android 14+）
**架构适用**: 所有架构
**最低版本**: Android 14 (API 34) for `android_network_packets`

### 所需采集配置

**必要源:**
- Perfetto data source: `android.network_packets` — 网络包追踪（Android 14+）

**增强源:**
- atrace category: `ss` — System Server 网络相关事件

### Perfetto 配置片段

```
data_sources {
  config {
    name: "android.network_packets"
    android_network_packets_config {
      poll_ms: 250
    }
  }
}
```

### 常见缺失原因
- 网络包追踪是 Android 14+ 新功能，旧版本不支持
- 旧版本可通过 `slice` 中的 OkHttp/Retrofit slice 间接分析（需应用内插桩）

---

## 电池/功耗分析 (battery_power)

**依赖表**: `android_battery_stats_state`, `android_battery_stats_event_slices`
**架构适用**: 所有架构
**最低版本**: Android 10 (API 29)

### 所需采集配置

**必要源:**
- atrace category: `power` — 电源管理事件
- Perfetto data source: `android.power` — 电池统计

**增强源:**
- atrace category: `battery_stats` — 电池状态变化

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      atrace_categories: "power"
      atrace_categories: "battery_stats"
    }
  }
}
data_sources {
  config {
    name: "android.power"
    android_power_config {
      battery_poll_ms: 1000
      collect_power_rails: true
    }
  }
}
```

### 常见缺失原因
- `android.power` data source 需要单独配置
- Power rails 数据依赖设备硬件支持（主要 Pixel 设备）
- 充电状态下 battery stats 数据可能不准确

---

## IRQ/中断分析 (interrupts)

**依赖表**: `linux_hard_irqs`, `linux_soft_irqs`
**架构适用**: 所有架构
**最低版本**: 任意版本

### 所需采集配置

**必要源:**
- ftrace event: `irq/irq_handler_entry` — 硬中断
- ftrace event: `irq/irq_handler_exit` — 硬中断结束
- ftrace event: `irq/softirq_entry` — 软中断
- ftrace event: `irq/softirq_exit` — 软中断结束

### Perfetto 配置片段

```
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      ftrace_events: "irq/irq_handler_entry"
      ftrace_events: "irq/irq_handler_exit"
      ftrace_events: "irq/softirq_entry"
      ftrace_events: "irq/softirq_exit"
    }
  }
}
```

### 常见缺失原因
- irq ftrace 事件通常需要显式启用（不在默认配置中）

---

## DMA-Buf/显存分析 (dmabuf)

**依赖表**: `android_dmabuf_allocs`, `android_memory_cumulative_dmabuf`
**架构适用**: 所有架构
**最低版本**: Android 12 (API 31)

### 所需采集配置

**必要源:**
- ftrace event: `dmabuf_heap/*` — DMA-Buf 堆事件

**增强源:**
- Perfetto data source: `gpu.memory` — GPU 内存追踪

### 常见缺失原因
- DMA-Buf tracing 需要 Android 12+ 内核支持
- 某些设备的 dmabuf_heap ftrace 事件不可用

---

## 设备状态 (device_state)

**依赖表**: `android_screen_state`, `android_suspend_state`, `android_charging_states`
**架构适用**: 所有架构
**最低版本**: Android 10 (API 29)

### 所需采集配置

**必要源:**
- atrace category: `power` — 设备电源状态
- ftrace event: `power/suspend_resume` — 休眠/唤醒

**增强源:**
- Perfetto data source: `android.polled_state` — 屏幕状态轮询

### 常见缺失原因
- `android_screen_state` 依赖 `power` atrace 或 `android.polled_state`
- v56+ stdlib 会用 `unknown`/`awake` 兜底补齐 trace 边界缺口；这些兜底行只能说明采集覆盖不足，不能当作“设备一直 awake / 状态没有变化”的强证据
- 某些自动化测试环境屏蔽了设备状态事件

---

## ANR 分析 (anr)

**依赖表**: `android_anrs`
**架构适用**: 所有架构
**最低版本**: Android 11 (API 30)

### 所需采集配置

**必要源:**
- atrace category: `am` — ActivityManager ANR 事件
- 足够长的 trace 时长（ANR timeout 通常 5-10 秒）

### 常见缺失原因
- Trace 时长不够（需 >= 10 秒覆盖 ANR 超时周期）
- ANR 在 trace 窗口之外发生
- Android 10 的 `android_anrs` stdlib 支持有限

---

## Jank CUJ 分析 (jank_cuj)

**依赖表**: `android_jank_cuj`, `android_jank_cuj_render_thread`
**架构适用**: STANDARD, COMPOSE
**最低版本**: Android 12 (API 31)

### 所需采集配置

**必要源:**
- atrace category: `gfx` — 图形管线
- 应用使用了 Jank CUJ (Critical User Journey) 标注 API

### 常见缺失原因
- 大多数第三方应用不使用 Jank CUJ API（主要用于系统 UI）
- 需要 AOSP 系统应用或显式接入 CUJ 标注
