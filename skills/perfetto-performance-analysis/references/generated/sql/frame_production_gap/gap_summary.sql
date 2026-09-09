-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/frame_production_gap.skill.yaml
-- Source SHA-256: 221c153dbac8c5a1a4efd28a5c917e2ab50b05b1f9d7f87eab25292fd01ddff0
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

WITH
vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_config AS (
  SELECT COALESCE(
    (SELECT CAST(PERCENTILE(interval_ns, 50) AS INTEGER)
     FROM vsync_intervals
     WHERE interval_ns BETWEEN 4000000 AND 50000000),
    16666667
  ) as period_ns
),
-- 帧序列（按 present_ts 排序）
frame_seq AS (
  SELECT
    a.display_frame_token as frame_id,
    a.ts as frame_start,
    a.ts + a.dur as frame_end,
    a.dur,
    a.upid,
    a.layer_name,
    -- 此前所有帧区间的覆盖终点；嵌套/重叠帧不能制造假 gap
    MAX(a.ts + a.dur) OVER (PARTITION BY a.upid, a.layer_name ORDER BY a.ts
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) as prev_frame_end
  FROM actual_frame_timeline_slice a
  JOIN process p ON a.upid = p.upid
  WHERE (${__process_scope.upid} IS NULL OR p.upid = ${__process_scope.upid})
    AND (${__process_scope.upid} IS NOT NULL OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
    AND a.dur > 0
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
-- Gap 检测：帧间隔 > min_gap_vsync × VSync
gaps AS (
  SELECT
    (SELECT CAST(a.display_frame_token AS TEXT)
     FROM actual_frame_timeline_slice a
     WHERE a.upid = fs.upid AND a.layer_name IS fs.layer_name
       AND a.ts + a.dur = fs.prev_frame_end AND a.ts < fs.frame_start
     ORDER BY a.ts DESC, a.display_frame_token DESC LIMIT 1) as before_frame_id,
    fs.frame_id as after_frame_id,
    fs.prev_frame_end as gap_start,
    fs.frame_start as gap_end,
    fs.frame_start - fs.prev_frame_end as gap_ns,
    ROUND((fs.frame_start - fs.prev_frame_end) / 1e6, 2) as gap_ms,
    ROUND((fs.frame_start - fs.prev_frame_end) * 1.0 / vc.period_ns, 1) as gap_vsync_count,
    fs.upid, fs.layer_name
  FROM frame_seq fs
  CROSS JOIN vsync_config vc
  WHERE fs.prev_frame_end IS NOT NULL
    AND (fs.frame_start - fs.prev_frame_end) > vc.period_ns * COALESCE(${min_gap_vsync}, 1.5)
    AND (fs.frame_start - fs.prev_frame_end) < vc.period_ns * 30  -- 排除非滑动 gap
),
-- Gap 期间 UI Thread / RenderThread 活动检测
-- 先筛选 main thread + RenderThread 的 utid，避免全线程笛卡尔积
relevant_threads AS (
  SELECT DISTINCT t.utid, t.tid, t.upid,
    CASE WHEN t.tid = p.pid THEN 'main' ELSE 'render' END as role
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NULL OR p.upid = ${__process_scope.upid})
    AND (${__process_scope.upid} IS NOT NULL OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
    AND p.name NOT LIKE '/system/%'
    AND (t.tid = p.pid OR t.name = 'RenderThread')
),
gap_ui_activity AS (
  SELECT
    g.upid, g.layer_name, g.gap_start,
    g.gap_end,
    COUNT(DISTINCT CASE WHEN rt.role = 'main' AND s.name LIKE 'Choreographer#doFrame%' AND s.name NOT GLOB '*resynced*' THEN s.id END) as doframe_count,
    COUNT(DISTINCT CASE WHEN rt.role = 'render' AND (s.name LIKE 'DrawFrame%' OR s.name LIKE 'draw:%') THEN s.id END) as drawframe_count
  FROM gaps g
  JOIN relevant_threads rt ON rt.upid = g.upid
  JOIN thread_track tt ON tt.utid = rt.utid
  JOIN slice s ON s.track_id = tt.id
    AND s.ts < g.gap_end AND (s.dur = -1 OR s.ts + s.dur > g.gap_start)
    AND (s.dur > 0 OR s.dur = -1)
  GROUP BY g.upid, g.layer_name, g.gap_start, g.gap_end
),
-- Gap 分类
classified_gaps AS (
  SELECT
    g.*,
    COALESCE(ua.doframe_count, 0) as doframe_count,
    COALESCE(ua.drawframe_count, 0) as drawframe_count,
    CASE
      WHEN COALESCE(ua.doframe_count, 0) = 0 THEN 'ui_no_frame'
      WHEN COALESCE(ua.drawframe_count, 0) = 0 THEN 'rt_no_drawframe'
      ELSE 'drawframe_observed'
    END as gap_type
  FROM gaps g
  LEFT JOIN gap_ui_activity ua ON ua.upid = g.upid AND ua.layer_name IS g.layer_name
  AND ua.gap_start = g.gap_start AND ua.gap_end = g.gap_end
)
SELECT
  'observed_marker_coverage_only' as evidence_scope,
  (SELECT COUNT(*) FROM frame_seq) as total_frames,
  COUNT(*) as total_gaps,
  SUM(CASE WHEN gap_type = 'ui_no_frame' THEN 1 ELSE 0 END) as ui_no_frame_count,
  SUM(CASE WHEN gap_type = 'rt_no_drawframe' THEN 1 ELSE 0 END) as rt_no_drawframe_count,
  SUM(CASE WHEN gap_type = 'drawframe_observed' THEN 1 ELSE 0 END) as drawframe_observed_count,
  MAX(gap_ms) as max_gap_ms,
  (SELECT ROUND(period_ns / 1e6, 2) FROM vsync_config) as vsync_period_ms
FROM classified_gaps
