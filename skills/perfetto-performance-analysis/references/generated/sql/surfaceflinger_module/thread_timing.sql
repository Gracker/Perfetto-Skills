-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/surfaceflinger_module.skill.yaml
-- Source SHA-256: 1ab8ca32abdfd4935e0a65eb1c83e73cb7d16dfac3a75a9ff0e24508f75769ba

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
