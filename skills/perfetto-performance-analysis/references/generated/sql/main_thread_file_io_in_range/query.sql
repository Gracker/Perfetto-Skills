-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/main_thread_file_io_in_range.skill.yaml
-- Source SHA-256: 445bb9c9c1c3650896f9bc8d15f7338b57a09c8a28bc3a844cc4be55ae7e6a13
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND t.tid = p.pid
),
io_slices AS (
  SELECT
    s.name as io_slice,
    MIN(s.ts + s.dur, ${end_ts}) - MAX(s.ts, ${start_ts}) as clipped_dur
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN main_thread mt ON tt.utid = mt.utid
  WHERE s.ts < ${end_ts}
    AND s.ts + s.dur > ${start_ts}
    AND (
      lower(s.name) GLOB '*open*'
      OR lower(s.name) GLOB '*read*'
      OR lower(s.name) GLOB '*write*'
      OR lower(s.name) GLOB '*fsync*'
      OR lower(s.name) GLOB '*fdatasync*'
      OR lower(s.name) GLOB '*sqlite*'
      OR lower(s.name) GLOB '*database*'
      OR lower(s.name) GLOB '*file*'
      OR lower(s.name) GLOB '*disk*'
    )
)
SELECT
  io_slice,
  COUNT(*) as count,
  ROUND(SUM(clipped_dur) / 1e6, 2) as total_ms,
  ROUND(AVG(clipped_dur) / 1e6, 2) as avg_ms,
  ROUND(MAX(clipped_dur) / 1e6, 2) as max_ms,
  ROUND(100.0 * SUM(clipped_dur) / NULLIF(${end_ts} - ${start_ts}, 0), 1) as percent
FROM io_slices
WHERE clipped_dur >= ${min_dur_ns|500000}
GROUP BY io_slice
ORDER BY total_ms DESC
LIMIT ${top_k|10}
