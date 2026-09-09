-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/surfaceflinger_module.skill.yaml
-- Source SHA-256: a56ccb9b89cffa35d9a98573a6b43fbcaf3fba59658a7a74b91d4676d6947e05
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

WITH janky AS (
  SELECT
    a.jank_type,
    a.dur
  FROM actual_frame_timeline_slice a
  JOIN process p ON a.upid = p.upid
  WHERE
    a.surface_frame_token IS NOT NULL
    AND (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
    AND a.jank_type != 'None'
)
SELECT
  jank_type,
  CASE
    WHEN android_is_sf_jank_type(jank_type) THEN 'SurfaceFlinger'
    WHEN android_is_app_jank_type(jank_type) THEN 'App'
    WHEN jank_type GLOB '*Buffer Stuffing*' THEN 'Buffer'
    ELSE 'Other'
  END AS jank_cause,
  COUNT(*) AS count,
  ROUND(AVG(dur) / 1e6, 1) AS avg_dur_ms,
  ROUND(MAX(dur) / 1e6, 1) AS max_dur_ms
FROM janky
GROUP BY jank_type, jank_cause
ORDER BY count DESC
