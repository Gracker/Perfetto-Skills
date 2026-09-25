-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_app_background_power_state.skill.yaml
-- Source SHA-256: 4ce3166f6ef8db3eca68f7a14cb6d6164abb3f15de2db690e545acc15ef4ff86
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

WITH bounds AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS window_start,
    COALESCE(${end_ts}, trace_end()) AS window_end
),
frozen AS (
  SELECT
    e.ts,
    e.dur,
    e.pid,
    COALESCE(p.name, printf('pid:%d', e.pid)) AS process_name,
    e.unfreeze_reason_str AS unfreeze_reason,
    'freezer_slices' AS source
  FROM android_freezer_events AS e
  LEFT JOIN process AS p USING (upid)
),
clipped AS (
  SELECT
    f.*,
    MIN(f.ts + f.dur, b.window_end) - MAX(f.ts, b.window_start) AS clipped_dur
  FROM frozen AS f
  CROSS JOIN bounds AS b
  WHERE f.ts < b.window_end AND f.ts + f.dur > b.window_start
    AND (
      '${package}' = ''
      OR f.process_name = '${package}'
      OR f.process_name GLOB '${package}:*'
    )
),
reasons AS (
  SELECT
    process_name,
    pid,
    unfreeze_reason,
    ROW_NUMBER() OVER (
      PARTITION BY process_name, pid ORDER BY COUNT(*) DESC, unfreeze_reason
    ) AS reason_rank
  FROM clipped
  WHERE unfreeze_reason IS NOT NULL
  GROUP BY process_name, pid, unfreeze_reason
)
SELECT
  c.process_name,
  c.pid,
  COUNT(*) AS freeze_count,
  ROUND(SUM(c.clipped_dur) / 1e6, 2) AS total_frozen_ms,
  ROUND(MAX(c.clipped_dur) / 1e6, 2) AS max_frozen_ms,
  r.unfreeze_reason AS top_unfreeze_reason,
  c.source
FROM clipped AS c
LEFT JOIN reasons AS r
  ON r.process_name = c.process_name
  AND r.pid = c.pid
  AND r.reason_rank = 1
GROUP BY c.process_name, c.pid, c.source
ORDER BY SUM(c.clipped_dur) DESC
LIMIT 50
