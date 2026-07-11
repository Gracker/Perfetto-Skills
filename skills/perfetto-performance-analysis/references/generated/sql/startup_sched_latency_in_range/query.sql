-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_sched_latency_in_range.skill.yaml
-- Source SHA-256: 2dff6eedc8bbd571f995c4eafe43f22357f71ad1b391939d8188bf3d6dbb0213
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  ts.state,
  COUNT(*) as count,
  SUM(ts.dur) / 1e6 as total_wait_ms,
  ROUND(AVG(ts.dur) / 1e6, 2) as avg_wait_ms,
  ROUND(MAX(ts.dur) / 1e6, 2) as max_wait_ms,
  SUM(CASE WHEN ts.dur / 1e6 > 8 THEN 1 ELSE 0 END) as severe_delays
FROM thread_state ts
JOIN android_startup_threads st ON ts.utid = st.utid
JOIN android_startups s ON st.startup_id = s.startup_id
WHERE st.is_main_thread = 1
  AND (s.package GLOB '${package}*' OR '${package}' = '')
  AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND ts.state IN ('R', 'R+')
  AND ts.ts >= s.ts
  AND ts.ts <= s.ts + s.dur
GROUP BY ts.state
