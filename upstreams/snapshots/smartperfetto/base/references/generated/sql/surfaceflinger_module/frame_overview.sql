-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/surfaceflinger_module.skill.yaml
-- Source SHA-256: a56ccb9b89cffa35d9a98573a6b43fbcaf3fba59658a7a74b91d4676d6947e05
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH frames AS (
  SELECT
    a.ts,
    a.dur,
    a.jank_type
  FROM actual_frame_timeline_slice a
  JOIN process p ON a.upid = p.upid
  WHERE
    a.surface_frame_token IS NOT NULL
    AND (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
)
SELECT
  COUNT(*) AS total_frames,
  SUM(CASE WHEN jank_type != 'None' THEN 1 ELSE 0 END) AS jank_count,
  ROUND(SUM(CASE WHEN jank_type != 'None' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS jank_rate,
  ROUND(1e9 * COUNT(*) / NULLIF((MAX(ts + dur) - MIN(ts)), 0), 1) AS avg_fps,
  ROUND(AVG(dur) / 1e6, 1) AS avg_frame_ms
FROM frames
