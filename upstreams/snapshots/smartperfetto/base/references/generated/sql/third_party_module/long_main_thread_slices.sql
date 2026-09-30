-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: 187161c0bb28c5b2c3fc7793981fd519e399d3a17ee5a07d05ea9d64daf388b5

SELECT
  slice.ts,
  slice.name AS task_name,
  CAST(slice.dur / 1e6 AS REAL) AS dur_ms,
  slice.depth
FROM slice
JOIN thread_track ON slice.track_id = thread_track.id
JOIN thread ON thread_track.utid = thread.utid
JOIN process ON thread.upid = process.upid
WHERE thread.name = 'main'
  AND ('${package}' = '' OR process.name = '${package}' OR process.name GLOB '${package}:*')
  AND slice.dur > 5000000
  AND slice.depth < 3
ORDER BY slice.dur DESC
LIMIT 30
