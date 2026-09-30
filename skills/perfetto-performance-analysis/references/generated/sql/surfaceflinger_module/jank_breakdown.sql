-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/surfaceflinger_module.skill.yaml
-- Source SHA-256: e3f857a0ef0e7ea322a5a6f0f6e2f13149fe4684ded79833c5a1421a53b93124

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
