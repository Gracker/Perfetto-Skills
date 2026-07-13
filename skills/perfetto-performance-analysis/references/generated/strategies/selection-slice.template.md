GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/selection-slice.template.md
Source SHA-256: 564366085a8bf47a77e08a4041bdda2d0c8581c8febb8b9f6c45ee3cbafff681
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

# Selection Slice Template

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

<!-- Template variables (substituted by claudeSystemPrompt.ts):
  {{eventId}}     - Slice ID (number)
  {{ts}}          - Slice start timestamp in ns (number)
  {{durationStr}} - Human-readable duration, e.g. "21.52 ms"
  {{sliceEnd}}    - Expression for Slice end: "ts+dur" or "ts" if dur unknown
  {{name}}        - Slice name (pre-queried, may be empty)
  {{threadName}}  - Thread name (pre-queried, may be empty)
  {{processName}} - Process name (pre-queried, may be empty)
  {{depth}}       - Slice depth in call stack (pre-queried, may be empty)
  {{childCount}}  - Number of direct children (pre-queried, may be empty)
-->
## 用户选区上下文

用户在 Perfetto UI 中选择了一个 Slice：
- **Slice ID:** {{eventId}}
- **名称:** {{name}}
- **时间戳:** {{ts}} ns
- **持续时间:** {{durationStr}}
- **线程:** {{threadName}}
- **进程:** {{processName}}
- **调用深度:** {{depth}}，**子调用数:** {{childCount}}

> 以上信息已由前端预查询，**无需再查 slice 基础信息**，直接从子调用链分析开始。
> 如果请求中附带了"前端预查询 Trace 数据"，优先使用，跳过对应的 SQL 步骤。

**分析约束:**
- 当用户提到"这个 Slice"/"选中的"/"selected slice"等，指的就是此 Slice
- 分析围绕此 Slice 展开：子调用链 → 耗时异常判断 → 根因
- 默认先做**快速 scoped 分析**，不要启动完整计划；只有用户明确问"为什么/根因/深入/详细分析"时才展开深挖
- 如果这是 `Actual Timeline` / `Expected Timeline` / FrameTimeline 相关 slice，优先回答这一帧的 expected 时间、actual 时间、最终 SF present 时间和 jank 状态；无 jank 时直接停止，不要继续跑全量 plan

**高效分析策略（严格遵循，避免超时）:**
1. **跳过基础信息查询**（名称/线程/进程已知），直接查子 Slice 树
2. 如果前端预查询数据里有 `selected FrameTimeline frame`，直接使用它回答；没有时可先运行下面的 FrameTimeline 快速查询，0 行则回到普通 Slice 分析
3. 查历史同类 Slice 做对比 → 判断是否异常
4. **仅当 thread_state 有数据时**才分析调度状态，否则跳过并注明"该时间段无调度数据"
5. 直接出结论 — 不要为空结果重试更大时间窗口

**FrameTimeline 快速查询模板（只用于 Actual/Expected Timeline 选中帧）:**
```sql
WITH selected AS (
  SELECT 'actual' AS selected_kind, id, name, upid, display_frame_token,
         surface_frame_token, layer_name
  FROM actual_frame_timeline_slice WHERE id = {{eventId}}
  UNION ALL
  SELECT 'expected' AS selected_kind, id, name, upid, display_frame_token,
         surface_frame_token, layer_name
  FROM expected_frame_timeline_slice WHERE id = {{eventId}}
),
frame_key AS (SELECT * FROM selected LIMIT 1),
expected_match AS (
  SELECT e.* FROM expected_frame_timeline_slice e
  JOIN frame_key k ON e.upid = k.upid AND e.name = k.name
  ORDER BY e.id LIMIT 1
),
actual_match AS (
  SELECT a.* FROM actual_frame_timeline_slice a
  JOIN frame_key k ON
    (a.id = k.id AND k.selected_kind = 'actual')
    OR (a.upid = k.upid AND a.name = k.name)
    OR (k.display_frame_token IS NOT NULL AND a.display_frame_token = k.display_frame_token AND a.upid = k.upid)
  ORDER BY CASE WHEN a.id = k.id THEN 0 ELSE 1 END, a.dur DESC LIMIT 1
),
sf_match AS (
  SELECT sf.* FROM actual_frame_timeline_slice sf
  JOIN actual_match a ON a.display_frame_token IS NOT NULL AND sf.display_frame_token = a.display_frame_token
  WHERE sf.surface_frame_token IS NULL
  ORDER BY sf.ts + sf.dur DESC LIMIT 1
)
SELECT
  k.selected_kind,
  k.id AS selected_id,
  COALESCE(a.name, e.name, k.name) AS frame_id,
  COALESCE(a.layer_name, e.layer_name, k.layer_name) AS layer_name,
  p.name AS process_name,
  ROUND(e.dur/1e6, 2) AS expected_ms,
  e.ts AS expected_start_ns,
  e.ts + e.dur AS expected_end_ns,
  ROUND(a.dur/1e6, 2) AS actual_ms,
  a.ts AS actual_start_ns,
  a.ts + a.dur AS actual_end_ns,
  sf.ts + sf.dur AS sf_present_ns,
  a.present_type,
  a.on_time_finish,
  a.jank_type,
  a.jank_severity_type,
  a.prediction_type
FROM frame_key k
LEFT JOIN expected_match e ON 1 = 1
LEFT JOIN actual_match a ON 1 = 1
LEFT JOIN sf_match sf ON 1 = 1
LEFT JOIN process p ON p.upid = COALESCE(a.upid, e.upid, k.upid);
```
> 如果 `jank_type` 为空或 `None` 且 `on_time_finish=1`，只输出 expected/actual/SF present 时间和"未见 FrameTimeline jank"；不要继续做卡顿根因分析。只有 `jank_type != 'None'` 时，才用同一帧的 start/end 轻量补查卡顿原因。

**普通 Slice 分析查询模板（FrameTimeline 快速查询 0 行时使用）:**
```sql
-- 1) 子 Slice 树（用 parent_id，不要用 track_id+ts 范围）
SELECT id, name, ts, dur, ROUND(dur/1e6,2) AS dur_ms, depth,
       ROUND(dur * 100.0 / (SELECT dur FROM slice WHERE id = {{eventId}}), 1) AS pct
FROM slice WHERE parent_id = {{eventId}}
ORDER BY ts;

-- 2) thread_state 调度状态（合并为一条查询，避免空查浪费）
SELECT thread_state.cpu, thread_state.state, COUNT(*) AS cnt, SUM(thread_state.dur)/1e6 AS total_ms
FROM thread_state
WHERE thread_state.utid = (SELECT tt.utid FROM slice s JOIN thread_track tt ON s.track_id=tt.id WHERE s.id={{eventId}})
  AND thread_state.ts >= {{ts}} AND thread_state.ts <= {{sliceEnd}}
GROUP BY thread_state.cpu, thread_state.state ORDER BY total_ms DESC;
-- ↑ 若返回 0 行，说明该时间段无 thread_state 数据，直接跳过调度分析

-- 3) 历史同类 Slice 对比（判断异常）
SELECT s.name AS slice_name, COUNT(*) AS cnt,
       ROUND(AVG(s.dur)/1e6,2) AS avg_ms,
       ROUND(MIN(s.dur)/1e6,2) AS min_ms,
       ROUND(MAX(s.dur)/1e6,2) AS max_ms
FROM slice s
WHERE s.track_id = (SELECT track_id FROM slice WHERE id = {{eventId}})
  AND s.name LIKE '{{name}}%'
GROUP BY s.name ORDER BY cnt DESC LIMIT 5;
```
> **关键**: 用 `parent_id` 遍历 Slice 层级，不要用 `track_id + ts BETWEEN`（后者经常返回空）。
> 如果 thread_state 查询返回空，直接跳过——不要扩大时间窗口重试。
