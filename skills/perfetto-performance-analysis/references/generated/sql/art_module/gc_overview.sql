-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/art_module.skill.yaml
-- Source SHA-256: d1467599deb13369b60c04f0f0e38ee4ce36e11b4e96df90b7f409300d451d3f
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  slice.name AS gc_type,
  COUNT(*) AS gc_count,
  CAST(SUM(slice.dur) / 1e6 AS INTEGER) AS total_gc_ms,
  CAST(AVG(slice.dur) / 1e6 AS REAL) AS avg_gc_ms,
  CAST(MAX(slice.dur) / 1e6 AS REAL) AS max_gc_ms
FROM slice
JOIN thread_track ON slice.track_id = thread_track.id
JOIN thread ON thread_track.utid = thread.utid
WHERE slice.name LIKE '%GC%'
  OR slice.name LIKE '%garbage%'
  OR slice.name LIKE '%collection%'
GROUP BY slice.name
ORDER BY total_gc_ms DESC
