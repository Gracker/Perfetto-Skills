-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/surfaceflinger_module.skill.yaml
-- Source SHA-256: a56ccb9b89cffa35d9a98573a6b43fbcaf3fba59658a7a74b91d4676d6947e05
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  'MainThread' AS thread,
  ROUND(AVG(s.dur) / 1e6, 1) AS avg_ms,
  SUM(CASE WHEN s.dur > 8e6 THEN 1 ELSE 0 END) AS overrun_count
FROM android_frames_choreographer_do_frame f
JOIN slice s ON f.id = s.id
JOIN process p ON f.upid = p.upid
WHERE (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
UNION ALL
SELECT
  'RenderThread' AS thread,
  ROUND(AVG(s.dur) / 1e6, 1) AS avg_ms,
  SUM(CASE WHEN s.dur > 8e6 THEN 1 ELSE 0 END) AS overrun_count
FROM android_frames_draw_frame f
JOIN slice s ON f.id = s.id
JOIN process p ON f.upid = p.upid
WHERE (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
