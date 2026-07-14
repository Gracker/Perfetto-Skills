-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: cdec84f3101148083ffa1b4e4d4fd0fd16bfcac16c0a71b257ca50f86c84311c
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*' AND t.tid = p.pid
  LIMIT 1
),
top_gc AS (
  SELECT ts, dur, gc_name
  FROM _gc_events
  WHERE is_main_thread = 1
    AND dur > 5000000  -- > 5ms
  ORDER BY dur DESC
  LIMIT 10
)
SELECT
  gc.gc_name as gc_type,
  gc.dur / 1e6 as gc_dur_ms,
  ts.state,
  SUM(
    CASE
      WHEN ts.ts + ts.dur <= gc.ts THEN 0
      WHEN ts.ts >= gc.ts + gc.dur THEN 0
      ELSE MIN(ts.ts + ts.dur, gc.ts + gc.dur) - MAX(ts.ts, gc.ts)
    END
  ) / 1e6 as state_dur_ms,
  ts.blocked_function
FROM top_gc gc
JOIN thread_state ts ON ts.utid = (SELECT utid FROM main_thread)
WHERE ts.ts + ts.dur > gc.ts
  AND ts.ts < gc.ts + gc.dur
GROUP BY gc.ts, ts.state, ts.blocked_function
ORDER BY gc.dur DESC, state_dur_ms DESC
LIMIT 30
