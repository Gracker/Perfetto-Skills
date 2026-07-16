-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/compose_recomposition_hotspot.skill.yaml
-- Source SHA-256: 2895ae93d263a1097b752875bc22c0e4521e6f96b6ad4feb319da03a76a0d59b
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH
recompositions AS (
  SELECT
    s.id,
    s.ts,
    s.dur,
    s.ts + s.dur as ts_end,
    s.name as slice_name,
    s.process_name,
    s.thread_name,
    s.upid
  FROM thread_slice s
  WHERE (s.process_name GLOB '${package}*' OR '${package}' = '')
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
    AND (s.name GLOB 'Recompos*' OR s.name GLOB 'Compose:*' OR s.name GLOB '*CompositionLocal*')
    AND s.dur > 1000000
),
frame_budget AS (
  SELECT COALESCE(
    (SELECT CAST(PERCENTILE(dur, 0.5) AS INTEGER)
     FROM actual_frame_timeline_slice
     WHERE dur BETWEEN 5000000 AND 50000000),
    16666667
  ) as budget_ns
),
frames AS (
  SELECT
    a.ts,
    a.dur,
    a.ts + a.dur as ts_end,
    COALESCE(a.display_frame_token, a.surface_frame_token) as frame_id,
    COALESCE(a.jank_type, 'None') as jank_type,
    a.upid
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
overlaps AS (
  SELECT
    r.*,
    f.frame_id,
    f.dur as frame_dur,
    f.jank_type,
    MAX(0, MIN(r.ts_end, f.ts_end) - MAX(r.ts, f.ts)) as overlap_ns
  FROM recompositions r
  JOIN frames f ON f.upid = r.upid
    AND r.ts < f.ts_end
    AND r.ts_end > f.ts
)
SELECT
  printf('%d', ts) as ts,
  printf('%d', dur) as dur_ns,
  ROUND(dur / 1e6, 2) as recomposition_ms,
  slice_name,
  process_name,
  thread_name,
  CAST(frame_id AS TEXT) as frame_id,
  ROUND(frame_dur / 1e6, 2) as frame_dur_ms,
  jank_type,
  ROUND(overlap_ns / 1e6, 2) as overlap_ms,
  CASE
    WHEN jank_type != 'None' AND dur > (SELECT budget_ns FROM frame_budget) THEN 'critical'
    WHEN frame_dur > (SELECT budget_ns * 1.5 FROM frame_budget) THEN 'warning'
    WHEN dur > (SELECT budget_ns * 0.5 FROM frame_budget) THEN 'notice'
    ELSE 'normal'
  END as severity
FROM overlaps
WHERE overlap_ns > 500000
  AND (jank_type != 'None' OR frame_dur > (SELECT budget_ns * 1.5 FROM frame_budget) OR dur > (SELECT budget_ns * 0.5 FROM frame_budget))
ORDER BY
  CASE severity WHEN 'critical' THEN 0 WHEN 'warning' THEN 1 WHEN 'notice' THEN 2 ELSE 3 END,
  dur DESC
LIMIT 100
