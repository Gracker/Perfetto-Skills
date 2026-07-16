-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH
-- 1. VSync config (同 scroll_sessions)
vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_config AS (
  SELECT CASE
    WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
    WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
    WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
    WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
    WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
    WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
    ELSE raw_ns
  END AS vsync_period_ns
  FROM (
    SELECT CAST(COALESCE(
      (SELECT PERCENTILE(interval_ns, 0.5)
       FROM vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
-- 2. Session boundaries (同 scroll_sessions)
frame_gaps AS (
  SELECT
    a.ts, a.dur, a.upid,
    p.name as process_name,
    a.ts - LAG(a.ts + a.dur) OVER (PARTITION BY a.upid ORDER BY a.ts) as gap_ns
  FROM actual_frame_timeline_slice a
  JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND a.dur > 0
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
session_markers AS (
  SELECT *,
    CASE WHEN gap_ns IS NULL OR gap_ns > (SELECT vsync_period_ns * 6 FROM vsync_config) THEN 1 ELSE 0 END as new_session
  FROM frame_gaps
),
sessions_raw AS (
  SELECT *,
    SUM(new_session) OVER (PARTITION BY upid ORDER BY ts) as session_id
  FROM session_markers
),
session_bounds AS (
  SELECT
    upid, session_id, process_name,
    MIN(ts) as start_ts,
    MAX(ts + dur) as end_ts
  FROM sessions_raw
  GROUP BY upid, session_id
  HAVING COUNT(*) >= 10
    AND (MAX(ts + dur) - MIN(ts)) > 200000000
),
-- 3. ONE scan of thread_state: 同时供四象限和大小核分布使用
thread_detail AS (
  SELECT
    sb.session_id,
    sb.process_name,
    CASE WHEN t.tid = p.pid THEN 'MainThread' ELSE t.name END as thread_name,
    ts.state,
    COALESCE(ct.core_type, 'unknown') as core_type,
    ts.dur
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  JOIN session_bounds sb ON p.upid = sb.upid
    AND ts.ts >= sb.start_ts AND ts.ts < sb.end_ts
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (t.tid = p.pid OR t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1'))
),
-- 4. 四象限聚合 (MainThread + RenderThread)
quadrant_agg AS (
  SELECT
    session_id, process_name,
    thread_name as thread,
    SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big') THEN dur ELSE 0 END) as q1_ns,
    SUM(CASE WHEN state = 'Running' AND core_type NOT IN ('prime', 'big') THEN dur ELSE 0 END) as q2_ns,
    SUM(CASE WHEN state = 'R' THEN dur ELSE 0 END) as q3_ns,
    SUM(CASE WHEN state IN ('D', 'DK') THEN dur ELSE 0 END) as q4a_ns,
    SUM(CASE WHEN state IN ('S', 'I') THEN dur ELSE 0 END) as q4b_ns,
    SUM(dur) as total_ns
  FROM thread_detail
  WHERE thread_name IN ('MainThread', 'RenderThread')
  GROUP BY session_id, process_name, thread_name
),
-- 5. 大小核分布聚合 (所有出图线程, Running 状态)
core_aff_raw AS (
  SELECT
    session_id, process_name, thread_name, core_type,
    SUM(CASE WHEN state = 'Running' THEN dur ELSE 0 END) as run_dur_ns
  FROM thread_detail
  GROUP BY session_id, process_name, thread_name, core_type
  HAVING SUM(CASE WHEN state = 'Running' THEN dur ELSE 0 END) > 0
),
core_aff_with_pct AS (
  SELECT ca.*,
    ROUND(100.0 * ca.run_dur_ns / NULLIF(
      SUM(ca.run_dur_ns) OVER (PARTITION BY ca.session_id, ca.process_name, ca.thread_name), 0
    ), 1) as pct
  FROM core_aff_raw ca
),
-- 6. CPU 频率聚合 (一次 counter 扫描)
cpu_freq_agg AS (
  SELECT
    sb.session_id, sb.process_name,
    ct.core_type,
    COUNT(DISTINCT cct.cpu) as num_cores,
    ROUND(AVG(c.value) / 1000, 0) as avg_freq_mhz,
    ROUND(MAX(c.value) / 1000, 0) as max_freq_mhz,
    ROUND(MIN(c.value) / 1000, 0) as min_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  JOIN _cpu_topology ct ON cct.cpu = ct.cpu_id
  JOIN session_bounds sb ON c.ts >= sb.start_ts AND c.ts < sb.end_ts
  WHERE cct.name = 'cpufreq'
  GROUP BY sb.session_id, sb.process_name, ct.core_type
)
-- 最终输出: 每个 session 一行, 3 个 JSON 列 + 匹配键
SELECT
  sb.session_id,
  sb.process_name,
  printf('%d', sb.start_ts) as start_ts,
  (SELECT json_group_array(json_object(
    'thread', sub.thread,
    'q1_big_pct', ROUND(100.0 * sub.q1_ns / NULLIF(sub.total_ns, 0), 1),
    'q2_little_pct', ROUND(100.0 * sub.q2_ns / NULLIF(sub.total_ns, 0), 1),
    'q3_runnable_pct', ROUND(100.0 * sub.q3_ns / NULLIF(sub.total_ns, 0), 1),
    'q4a_io_pct', ROUND(100.0 * sub.q4a_ns / NULLIF(sub.total_ns, 0), 1),
    'q4b_sleep_pct', ROUND(100.0 * sub.q4b_ns / NULLIF(sub.total_ns, 0), 1),
    'total_ms', ROUND(sub.total_ns / 1e6, 1)
  )) FROM (
    SELECT * FROM quadrant_agg qa
    WHERE qa.session_id = sb.session_id AND qa.process_name = sb.process_name
    ORDER BY CASE qa.thread WHEN 'MainThread' THEN 1 ELSE 2 END
  ) sub) as quadrant_json,
  (SELECT json_group_array(json_object(
    'core_type', sub.core_type,
    'num_cores', sub.num_cores,
    'avg_freq_mhz', sub.avg_freq_mhz,
    'max_freq_mhz', sub.max_freq_mhz,
    'min_freq_mhz', sub.min_freq_mhz
  )) FROM (
    SELECT * FROM cpu_freq_agg cf
    WHERE cf.session_id = sb.session_id AND cf.process_name = sb.process_name
    ORDER BY cf.max_freq_mhz DESC
  ) sub) as cpu_freq_json,
  (SELECT json_group_array(json_object(
    'thread_name', sub.thread_name,
    'core_type', sub.core_type,
    'run_ms', ROUND(sub.run_dur_ns / 1e6, 2),
    'pct', sub.pct
  )) FROM (
    SELECT * FROM core_aff_with_pct cap
    WHERE cap.session_id = sb.session_id AND cap.process_name = sb.process_name
    ORDER BY
      CASE cap.thread_name
        WHEN 'MainThread' THEN 1 WHEN 'RenderThread' THEN 2
        WHEN 'GPU completion' THEN 3 ELSE 4
      END, cap.run_dur_ns DESC
  ) sub) as core_affinity_json
FROM session_bounds sb
ORDER BY sb.start_ts
