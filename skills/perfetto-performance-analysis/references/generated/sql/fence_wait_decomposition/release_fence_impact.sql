-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/fence_wait_decomposition.skill.yaml
-- Source SHA-256: 75f359793eed661eb1be28d6514d7eca7a9defec4fa11b309b3166f25d9ee94a
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH
target_app_filter AS (
  SELECT p.upid
  FROM process p
  WHERE '${package}' = '' OR ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
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
  COALESCE((SELECT COUNT(*) FROM dequeue_slices WHERE dur_ns > 5e6), 0) as blocked_dequeue_count,
  -- Ledger columns. A window with no dequeueBuffer slices is reported as
  -- `unavailable`, not as a measured zero: the difference between "the
  -- producer never blocked" and "this trace does not carry the slice" is
  -- the whole point of asking.
  ${start_ts} as evidence_window_start_ts,
  ${end_ts} as evidence_window_end_ts,
  CASE WHEN (SELECT COUNT(*) FROM dequeue_slices) > 0
    THEN 'observed' ELSE 'unavailable' END as dequeue_evidence
