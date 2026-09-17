-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_sched_latency_in_range.skill.yaml
-- Source SHA-256: dcc810fd9781cf0cab752296caf935a196da4190f066c3c7f07eddd4b7868483
-- Source commit: e198ac39082cf1b029b0833e46e8ee49dd9387ce

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
  AND (('${package}' = '' OR s.package = '${package}' OR s.package GLOB '${package}:*') OR '${package}' = '')
  AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND ts.state IN ('R', 'R+')
  AND ts.ts >= s.ts
  AND ts.ts <= s.ts + s.dur
GROUP BY ts.state
