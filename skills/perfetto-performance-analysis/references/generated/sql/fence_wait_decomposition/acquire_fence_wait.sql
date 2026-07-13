-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/fence_wait_decomposition.skill.yaml
-- Source SHA-256: 182d5e6b03a0ccfbd53f5da992628513e87e9afe773539e0fc312d54148568af
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH
sf_proc AS (
  SELECT upid FROM process WHERE name = 'surfaceflinger' LIMIT 1
),
acquire_slices AS (
  SELECT s.dur as dur_ns
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE t.upid IN (SELECT upid FROM sf_proc)
    AND (s.name GLOB '*acquireBuffer*' OR s.name GLOB '*latchBuffer*')
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
    AND s.dur > 0
),
sorted_acquire AS (
  SELECT dur_ns, ROW_NUMBER() OVER (ORDER BY dur_ns) as rn,
         COUNT(*) OVER () as total
  FROM acquire_slices
)
SELECT
  (SELECT COUNT(*) FROM acquire_slices) as total_acquire_buffer,
  COALESCE((SELECT ROUND(AVG(dur_ns) / 1e6, 2) FROM acquire_slices), 0) as avg_acquire_ms,
  COALESCE((
    SELECT ROUND(dur_ns / 1e6, 2)
    FROM sorted_acquire
    WHERE rn = CAST(total * 0.95 AS INTEGER)
    LIMIT 1
  ), 0) as p95_acquire_ms,
  COALESCE((SELECT ROUND(MAX(dur_ns) / 1e6, 2) FROM acquire_slices), 0) as max_acquire_ms
