-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH main_quadrant AS (
  SELECT
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('prime', 'big') THEN ts.dur ELSE 0 END) as q1_ns,
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('medium', 'little') THEN ts.dur ELSE 0 END) as q2_ns,
    SUM(CASE WHEN ts.state = 'R' THEN ts.dur ELSE 0 END) as q3_ns,
    SUM(CASE WHEN ts.state IN ('D', 'DK') THEN ts.dur ELSE 0 END) as q4a_ns,
    SUM(CASE WHEN ts.state IN ('S', 'I') THEN ts.dur ELSE 0 END) as q4b_ns,
    SUM(ts.dur) as total_ns
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND t.tid = p.pid
    AND (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
),
render_quadrant AS (
  SELECT
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('prime', 'big') THEN ts.dur ELSE 0 END) as q1_ns,
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('medium', 'little') THEN ts.dur ELSE 0 END) as q2_ns,
    SUM(CASE WHEN ts.state = 'R' THEN ts.dur ELSE 0 END) as q3_ns,
    SUM(CASE WHEN ts.state IN ('D', 'DK') THEN ts.dur ELSE 0 END) as q4a_ns,
    SUM(CASE WHEN ts.state IN ('S', 'I') THEN ts.dur ELSE 0 END) as q4b_ns,
    SUM(ts.dur) as total_ns
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND t.name = 'RenderThread'
    AND (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
)
SELECT 'MainThread' as thread,
  ROUND(100.0 * q1_ns / NULLIF(total_ns, 0), 1) as q1_big_pct,
  ROUND(100.0 * q2_ns / NULLIF(total_ns, 0), 1) as q2_little_pct,
  ROUND(100.0 * q3_ns / NULLIF(total_ns, 0), 1) as q3_runnable_pct,
  ROUND(100.0 * q4a_ns / NULLIF(total_ns, 0), 1) as q4a_io_pct,
  ROUND(100.0 * q4b_ns / NULLIF(total_ns, 0), 1) as q4b_sleep_pct,
  ROUND(total_ns / 1e6, 2) as total_ms
FROM main_quadrant
UNION ALL
SELECT 'RenderThread' as thread,
  ROUND(100.0 * q1_ns / NULLIF(total_ns, 0), 1) as q1_big_pct,
  ROUND(100.0 * q2_ns / NULLIF(total_ns, 0), 1) as q2_little_pct,
  ROUND(100.0 * q3_ns / NULLIF(total_ns, 0), 1) as q3_runnable_pct,
  ROUND(100.0 * q4a_ns / NULLIF(total_ns, 0), 1) as q4a_io_pct,
  ROUND(100.0 * q4b_ns / NULLIF(total_ns, 0), 1) as q4b_sleep_pct,
  ROUND(total_ns / 1e6, 2) as total_ms
FROM render_quadrant
