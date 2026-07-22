-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/device_state_snapshot.skill.yaml
-- Source SHA-256: 886bf69ae41b697f5c80cad4e1787cc5198233e15f65cb3c9cb3d382ca3b3655
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH trace_bounds AS (
  SELECT
    COALESCE(${start_ts}, (SELECT MIN(ts) FROM slice)) as t_start,
    COALESCE(${end_ts}, (SELECT MAX(ts + dur) FROM slice)) as t_end
)
SELECT
  printf('%d', s.ts) as start_ts,
  printf('%d', s.ts + s.dur) as end_ts,
  ROUND(s.dur / 1000000.0, 2) as dur_ms,
  s.name as source
FROM slice s
CROSS JOIN trace_bounds tb
WHERE s.dur > 0
  AND s.ts + s.dur > tb.t_start
  AND s.ts < tb.t_end
  AND (
    s.name GLOB '*idle*'
    OR s.name GLOB '*Idle*'
    OR s.name GLOB '*suspend*'
    OR s.name GLOB '*doze*'
  )
ORDER BY s.dur DESC
LIMIT 20
