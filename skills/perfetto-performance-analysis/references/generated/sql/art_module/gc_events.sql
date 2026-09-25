-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/art_module.skill.yaml
-- Source SHA-256: ae5d2db90bbb80ca10096056d71b8feb7cde4b2284fdcbe629a2acb1abd990c1
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
