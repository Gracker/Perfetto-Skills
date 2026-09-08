-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/fence_wait_decomposition.skill.yaml
-- Source SHA-256: a932c07018ae1cdbedf22f4c468de729ebbda4baf16f1e1d0cf33b29f24196cd
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH
sf_proc AS (
  SELECT upid FROM process WHERE name = 'surfaceflinger' LIMIT 1
),
present_slices AS (
  SELECT s.dur as dur_ns
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE t.upid IN (SELECT upid FROM sf_proc)
    AND s.name GLOB '*presentDisplay*'
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
    AND s.dur > 0
),
sorted_present AS (
  SELECT dur_ns, ROW_NUMBER() OVER (ORDER BY dur_ns) as rn,
         COUNT(*) OVER () as total
  FROM present_slices
)
SELECT
  (SELECT COUNT(*) FROM present_slices) as total_present_display,
  COALESCE((SELECT ROUND(AVG(dur_ns) / 1e6, 2) FROM present_slices), 0) as avg_present_ms,
  COALESCE((
    SELECT ROUND(dur_ns / 1e6, 2)
    FROM sorted_present
    WHERE rn = CAST(total * 0.95 AS INTEGER)
    LIMIT 1
  ), 0) as p95_present_ms,
  COALESCE((SELECT COUNT(*) FROM present_slices WHERE dur_ns > 16e6), 0) as late_present_count
