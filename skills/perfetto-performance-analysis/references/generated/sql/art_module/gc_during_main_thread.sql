-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/art_module.skill.yaml
-- Source SHA-256: d1467599deb13369b60c04f0f0e38ee4ce36e11b4e96df90b7f409300d451d3f
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  slice.ts,
  slice.name AS gc_type,
  CAST(slice.dur / 1e6 AS REAL) AS dur_ms
FROM slice
JOIN thread_track ON slice.track_id = thread_track.id
JOIN thread ON thread_track.utid = thread.utid
JOIN process ON thread.upid = process.upid
WHERE (slice.name LIKE '%GC%' OR slice.name LIKE '%garbage%')
  AND thread.name = 'main'
  AND process.name LIKE '%${package}%'
ORDER BY slice.dur DESC
LIMIT 20
