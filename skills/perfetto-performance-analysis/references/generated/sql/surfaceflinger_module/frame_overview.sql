-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/surfaceflinger_module.skill.yaml
-- Source SHA-256: 8fb31a101cc4a8eb2f27ee6912d7f2050586b4cdc0b8722a544391b9c26cd7e0
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH frames AS (
  SELECT
    a.ts,
    a.dur,
    a.jank_type
  FROM actual_frame_timeline_slice a
  JOIN process p ON a.upid = p.upid
  WHERE
    a.surface_frame_token IS NOT NULL
    AND (p.name GLOB '${package}*' OR '${package}' = '')
)
SELECT
  COUNT(*) AS total_frames,
  SUM(CASE WHEN jank_type != 'None' THEN 1 ELSE 0 END) AS jank_count,
  ROUND(SUM(CASE WHEN jank_type != 'None' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS jank_rate,
  ROUND(1e9 * COUNT(*) / NULLIF((MAX(ts + dur) - MIN(ts)), 0), 1) AS avg_fps,
  ROUND(AVG(dur) / 1e6, 1) AS avg_frame_ms
FROM frames
