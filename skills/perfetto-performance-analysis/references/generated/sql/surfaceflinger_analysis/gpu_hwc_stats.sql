-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 59c8f596d0111ef62440eb05318e85cfc2368d1d0b62d50ed6b1147b21e58aac
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

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
