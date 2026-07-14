-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/scheduling_analysis.skill.yaml
-- Source SHA-256: 1e143b06981a9c0792d2263ba7c2d42a08a87a69f9257a6af7305abdc3080cab
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH target_threads AS (
  SELECT t.utid, t.tid, t.name as thread_name, p.pid, p.name as process_name
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*' OR '${package}' = ''
),
thread_states AS (
  SELECT
    ts.utid,
    ts.state,
    ts.dur,
    ts.ts
  FROM thread_state ts
  WHERE (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
    AND ts.utid IN (SELECT utid FROM target_threads)
)
SELECT
  tt.thread_name,
  tt.process_name,
  tt.tid = tt.pid as is_main_thread,
  SUM(CASE WHEN tst.state = 'Running' THEN tst.dur ELSE 0 END) / 1e6 as running_ms,
  SUM(CASE WHEN tst.state = 'R' THEN tst.dur ELSE 0 END) / 1e6 as runnable_ms,
  SUM(CASE WHEN tst.state IN ('S', 'D') THEN tst.dur ELSE 0 END) / 1e6 as sleeping_ms,
  MAX(CASE WHEN tst.state = 'R' THEN tst.dur ELSE 0 END) / 1e6 as max_runnable_ms,
  COUNT(CASE WHEN tst.state = 'R' AND tst.dur > 5000000 THEN 1 END) as long_runnable_count
FROM target_threads tt
LEFT JOIN thread_states tst ON tt.utid = tst.utid
GROUP BY tt.utid
HAVING running_ms > 0 OR runnable_ms > 0
ORDER BY runnable_ms DESC
