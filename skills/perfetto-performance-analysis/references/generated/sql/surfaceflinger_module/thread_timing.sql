-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/surfaceflinger_module.skill.yaml
-- Source SHA-256: d456d7df46f6aec95de47a77dc360d10ac0154b45fa9ed8e8a779c8ea356bffd
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

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
