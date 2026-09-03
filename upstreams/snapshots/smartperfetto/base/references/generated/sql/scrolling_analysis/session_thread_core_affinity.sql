-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 898b631aafbdad1f8c7fabc5e2a741fa750cf701ec82b9810adfd3e687b94431
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH thread_runs AS (
  SELECT
    CASE WHEN t.tid = p.pid THEN 'MainThread' ELSE t.name END as thread_name,
    COALESCE(ct.core_type, 'unknown') as core_type,
    SUM(ts.dur) as run_dur_ns
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE (
    '${package}' = ''
    OR p.name = '${package}'
    OR p.name GLOB '${package}:*'
  )
    AND p.name NOT LIKE '/system/%'
    AND ts.state = 'Running'
    AND (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
    AND (t.tid = p.pid OR t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1'))
  GROUP BY thread_name, core_type
)
SELECT
  thread_name,
  core_type,
  ROUND(run_dur_ns / 1e6, 2) as run_ms,
  ROUND(100.0 * run_dur_ns / NULLIF(SUM(run_dur_ns) OVER (PARTITION BY thread_name), 0), 1) as pct
FROM thread_runs
ORDER BY
  CASE thread_name
    WHEN 'MainThread' THEN 1
    WHEN 'RenderThread' THEN 2
    WHEN 'GPU completion' THEN 3
    ELSE 4
  END,
  run_dur_ns DESC
