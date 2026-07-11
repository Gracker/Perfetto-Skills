GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/selection-area.template.md
Source SHA-256: 3166bc6d4745e6b42148a4642349254d11d5b1dddb1a0aeaa7a6baa635462f76
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

# Selection Area Template

Portable methodology extracted from the SmartPerfetto strategy library.

<!-- Template variables (substituted by claudeSystemPrompt.ts):
  {{startNs}}     - Area start timestamp in ns (number)
  {{endNs}}       - Area end timestamp in ns (number)
  {{durationMs}}  - Duration in ms, e.g. "19.30"
  {{trackCount}}  - Number of selected tracks (number or "未知")
  {{trackSummary}} - Pre-formatted track list grouped by process (string, may be empty)
  {{sourceLabel}} - Selection source label, e.g. Perfetto area/time-range selection or current visible timeline window
-->
## 用户选区上下文

用户当前问题带有一个明确的时间范围 scope（来源: {{sourceLabel}}）：
- **起始时间:** {{startNs}} ns
- **结束时间:** {{endNs}} ns
- **持续时间:** {{durationMs}} ms
- **选中 Track 数:** {{trackCount}}{{trackSummary}}

**分析约束:**
- 选区/窗口只定义时间和可选 track scope；用户真正要看的指标由用户问题决定，不要用固定 pattern 代替意图判断
- SQL 查询必须限制在上述时间范围。对 `slice` / `thread_state` / `sched_slice` 这类带持续时间的表，优先使用 overlap clipping：`ts < {{endNs}} AND ts + dur > {{startNs}}`，并用 `MIN(ts + dur, {{endNs}}) - MAX(ts, {{startNs}})` 计算区间内贡献
- 上述时间戳是 trace_processor 原始时间戳（ns），可直接用于 slice/thread_state/sched 等所有表的 ts 列
- 分析结论应聚焦于用户选择的这段区间
- 如果需要全局上下文（如整体 VSync 周期）来做对比，可以额外查询，但核心分析范围是选区内
- 当用户提到"选中的区间"/"这一段"/"选择的范围"/"marked area"/"current window"等，指的就是上述时间窗口
- 如果前端请求附带了 `traceContext` datasets，优先复用其中已经预取的选区数据；缺少用户所问的指标时，再调用工具补齐



**选区内常用 SQL 查询模板（需要自定义 SQL 时使用）:**
```sql
-- 1) 选区内某线程的调度状态分布（大小核、Running/Sleeping/Runnable）
SELECT cpu, state,
       SUM(MIN(ts + dur, {{endNs}}) - MAX(ts, {{startNs}}))/1e6 AS total_ms,
       COUNT(*) AS count
FROM thread_state
WHERE utid = <UTID>
  AND ts < {{endNs}} AND ts + dur > {{startNs}}
GROUP BY cpu, state ORDER BY total_ms DESC;

-- 2) 选区内 CPU 频率变化（使用 counter + cpu_counter_track，不要用 cpu_frequency_counters）
SELECT ct.cpu, c.ts, c.value AS freq_khz
FROM counter c JOIN cpu_counter_track ct ON c.track_id = ct.id
WHERE ct.name = 'cpufreq' AND c.ts >= {{startNs}} AND c.ts <= {{endNs}}
ORDER BY ct.cpu, c.ts;

-- 3) 选区内某线程的 Slice 热点（通过 thread_track 关联）
SELECT s.name,
       (MIN(s.ts + s.dur, {{endNs}}) - MAX(s.ts, {{startNs}}))/1e6 AS dur_ms,
       s.ts, s.depth
FROM slice s JOIN thread_track tt ON s.track_id = tt.id
WHERE tt.utid = <UTID>
  AND s.ts < {{endNs}} AND s.ts + s.dur > {{startNs}}
ORDER BY s.dur DESC LIMIT 20;
```
> 注意: 不要猜测表名。如果不确定表是否存在，先用 `lookup_sql_schema` 工具查询。
