-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 883c9e637f8166269939f7f817af9ef900c89e2215ca90cb3c0ad0d45443daad
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH
sf_slices AS (
  SELECT
    s.ts,
    s.dur,
    s.name,
    CASE
      WHEN s.name GLOB '*GPU*' OR s.name GLOB '*gpu*' OR s.name GLOB '*GLES*' THEN 'GPU'
      WHEN s.name GLOB '*HWC*' OR s.name GLOB '*hwc*' OR s.name GLOB '*Client*' THEN 'HWC'
      ELSE 'Other'
    END as comp_type
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = 'surfaceflinger' OR p.name = '/system/bin/surfaceflinger')
    AND (s.name GLOB '*composite*' OR s.name GLOB '*Composite*'
         OR s.name GLOB '*GPU*' OR s.name GLOB '*HWC*')
    AND s.dur > 0
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
),
total AS (
  SELECT COUNT(*) as total_count FROM sf_slices
)
SELECT
  comp_type as composition_type,
  COUNT(*) as frame_count,
  ROUND(100.0 * COUNT(*) / NULLIF((SELECT total_count FROM total), 0), 1) as pct,
  CAST(ROUND(AVG(dur)) AS INTEGER) as avg_dur,
  MAX(dur) as max_dur
FROM sf_slices
GROUP BY comp_type
ORDER BY frame_count DESC
