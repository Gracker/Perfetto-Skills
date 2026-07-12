-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/main_thread_sched_latency_in_range.skill.yaml
-- Source SHA-256: de053b0fa4190314df852b3a55b169077626cae09d319365cdaff98c5ec3ad1e
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND t.tid = p.pid
)
SELECT
  'MainThread' as thread_name,
  COUNT(*) as runnable_count,
  ROUND(SUM(ts.dur) / 1e6, 2) as total_runnable_ms,
  ROUND(MAX(ts.dur) / 1e6, 2) as max_latency_ms,
  ROUND(AVG(ts.dur) / 1e6, 2) as avg_latency_ms,
  SUM(CASE WHEN ts.dur > 2000000 THEN 1 ELSE 0 END) as long_wait_count,
  SUM(CASE WHEN ts.dur > 8000000 THEN 1 ELSE 0 END) as severe_count
FROM thread_state ts
JOIN main_thread mt ON ts.utid = mt.utid
WHERE (${start_ts} IS NULL OR ts.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
  AND ts.state IN ('R', 'R+')
GROUP BY 1
HAVING total_runnable_ms > 0.01
