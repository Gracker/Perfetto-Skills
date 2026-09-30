-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/art_module.skill.yaml
-- Source SHA-256: e7d524de05ca91174a9bf283192a02d3dfab1324753b0b8ebfaaa259379d9e8a

SELECT
  slice.ts,
  slice.name AS gc_type,
  CAST(slice.dur / 1e6 AS REAL) AS dur_ms,
  thread.name AS thread_name
FROM slice
JOIN thread_track ON slice.track_id = thread_track.id
JOIN thread ON thread_track.utid = thread.utid
WHERE slice.name LIKE '%GC%'
  OR slice.name LIKE '%garbage%'
ORDER BY slice.dur DESC
LIMIT 30
