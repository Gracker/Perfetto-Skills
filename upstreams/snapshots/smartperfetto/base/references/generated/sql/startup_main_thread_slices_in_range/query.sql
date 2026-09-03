-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_main_thread_slices_in_range.skill.yaml
-- Source SHA-256: 21db5523aeee82a84c77686daadfba7b7a22178318b9d83514ecf380bd150af0
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH raw AS (
  SELECT
    ts.slice_name,
    ts.thread_name,
    ts.slice_dur,
    ts.slice_id,
    s.dur as startup_dur,
    '${startup_type}' as startup_type,
    s.package
  FROM android_thread_slices_for_all_startups ts
  JOIN android_startups s ON ts.startup_id = s.startup_id
  WHERE ts.is_main_thread = 1
    AND (('${package}' = '' OR s.package = '${package}' OR s.package GLOB '${package}:*') OR '${package}' = '')
    AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
    AND ts.slice_dur > ${min_dur_ns|1000000}
),
with_self AS (
  SELECT
    r.*,
    r.slice_dur - COALESCE((
      SELECT SUM(c.dur)
      FROM slice c
      WHERE c.parent_id = r.slice_id
    ), 0) as self_dur
  FROM raw r
)
SELECT
  slice_name,
  thread_name,
  COUNT(*) as count,
  SUM(slice_dur) / 1e6 as total_dur_ms,
  ROUND(SUM(self_dur) / 1e6, 2) as self_dur_ms,
  ROUND(AVG(slice_dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(slice_dur) / 1e6, 2) as max_dur_ms,
  ROUND(100.0 * SUM(slice_dur) / startup_dur, 1) as percent_of_startup,
  ROUND(100.0 * SUM(self_dur) / startup_dur, 1) as self_percent,
  startup_type,
  package
FROM with_self
GROUP BY slice_name
ORDER BY total_dur_ms DESC
LIMIT ${top_k|15}
