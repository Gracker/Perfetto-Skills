-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/fence_wait_decomposition.skill.yaml
-- Source SHA-256: 182d5e6b03a0ccfbd53f5da992628513e87e9afe773539e0fc312d54148568af
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH
target_app_filter AS (
  SELECT p.upid
  FROM process p
  WHERE '${package}' = '' OR p.name GLOB '${package}*'
),
dequeue_slices AS (
  SELECT s.dur as dur_ns
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE t.upid IN (SELECT upid FROM target_app_filter)
    AND s.name GLOB '*dequeueBuffer*'
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
    AND s.dur > 0
),
sorted_dequeue AS (
  SELECT dur_ns, ROW_NUMBER() OVER (ORDER BY dur_ns) as rn,
         COUNT(*) OVER () as total
  FROM dequeue_slices
)
SELECT
  (SELECT COUNT(*) FROM dequeue_slices) as total_dequeue_buffer,
  COALESCE((SELECT ROUND(AVG(dur_ns) / 1e6, 2) FROM dequeue_slices), 0) as avg_dequeue_ms,
  COALESCE((
    SELECT ROUND(dur_ns / 1e6, 2)
    FROM sorted_dequeue
    WHERE rn = CAST(total * 0.95 AS INTEGER)
    LIMIT 1
  ), 0) as p95_dequeue_ms,
  COALESCE((SELECT COUNT(*) FROM dequeue_slices WHERE dur_ns > 5e6), 0) as blocked_dequeue_count
