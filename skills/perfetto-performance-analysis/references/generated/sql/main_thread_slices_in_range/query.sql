-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/main_thread_slices_in_range.skill.yaml
-- Source SHA-256: 92c26f5fe09128479cfc14d876cfbcd7f894ba46ddf9121de2565125973321c0
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (
      (${upid|0} > 0 AND p.upid = ${upid|0})
      OR (${upid|0} <= 0 AND ${pid|0} > 0 AND p.pid = ${pid|0}
          AND ('${package|}' = '' OR p.name = '${package|}' OR p.name GLOB '${package|}:*'))
      OR (${upid|0} <= 0 AND ${pid|0} <= 0
          AND ('${package|}' = '' OR p.name = '${package|}' OR p.name GLOB '${package|}:*'))
    )
    AND t.tid = p.pid
),
-- Compute per-slice self_dur (exclusive time = wall time - direct children time)
slice_with_self AS (
  SELECT
    s.id,
    s.name as slice_name,
    MIN(CASE WHEN s.dur < 0 THEN ${end_ts} ELSE s.ts + s.dur END, ${end_ts}) - MAX(s.ts, ${start_ts}) as clipped_dur,
    -- Self dur = clipped wall time minus clipped children time
    (MIN(CASE WHEN s.dur < 0 THEN ${end_ts} ELSE s.ts + s.dur END, ${end_ts}) - MAX(s.ts, ${start_ts}))
      - COALESCE((
          SELECT SUM(
            MIN(
              CASE WHEN c.dur < 0 THEN ${end_ts} ELSE c.ts + c.dur END,
              MIN(CASE WHEN s.dur < 0 THEN ${end_ts} ELSE s.ts + s.dur END, ${end_ts})
            )
            - MAX(c.ts, MAX(s.ts, ${start_ts}))
          )
          FROM slice c
          WHERE c.parent_id = s.id
            AND c.ts < ${end_ts}
            AND (CASE WHEN c.dur < 0 THEN ${end_ts} ELSE c.ts + c.dur END) > ${start_ts}
        ), 0) as self_dur
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN main_thread mt ON tt.utid = mt.utid
  WHERE s.ts < ${end_ts}
    AND (CASE WHEN s.dur < 0 THEN ${end_ts} ELSE s.ts + s.dur END) > ${start_ts}
)
SELECT
  slice_name,
  COUNT(*) as count,
  ROUND(SUM(clipped_dur) / 1e6, 2) as total_ms,
  ROUND(SUM(self_dur) / 1e6, 2) as self_ms,
  ROUND(AVG(clipped_dur) / 1e6, 2) as avg_ms,
  ROUND(MAX(clipped_dur) / 1e6, 2) as max_ms,
  ROUND(100.0 * SUM(clipped_dur) / NULLIF(${end_ts} - ${start_ts}, 0), 1) as percent,
  ROUND(100.0 * SUM(self_dur) / NULLIF(${end_ts} - ${start_ts}, 0), 1) as self_percent
FROM slice_with_self
WHERE clipped_dur >= ${min_dur_ns|1000000}
GROUP BY slice_name
ORDER BY total_ms DESC
LIMIT ${top_k|10}
