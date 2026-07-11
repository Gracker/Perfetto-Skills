-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/surfaceflinger_module.skill.yaml
-- Source SHA-256: 8fb31a101cc4a8eb2f27ee6912d7f2050586b4cdc0b8722a544391b9c26cd7e0
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  'MainThread' AS thread,
  ROUND(AVG(s.dur) / 1e6, 1) AS avg_ms,
  SUM(CASE WHEN s.dur > 8e6 THEN 1 ELSE 0 END) AS overrun_count
FROM android_frames_choreographer_do_frame f
JOIN slice s ON f.id = s.id
JOIN process p ON f.upid = p.upid
WHERE (p.name GLOB '${package}*' OR '${package}' = '')
UNION ALL
SELECT
  'RenderThread' AS thread,
  ROUND(AVG(s.dur) / 1e6, 1) AS avg_ms,
  SUM(CASE WHEN s.dur > 8e6 THEN 1 ELSE 0 END) AS overrun_count
FROM android_frames_draw_frame f
JOIN slice s ON f.id = s.id
JOIN process p ON f.upid = p.upid
WHERE (p.name GLOB '${package}*' OR '${package}' = '')
