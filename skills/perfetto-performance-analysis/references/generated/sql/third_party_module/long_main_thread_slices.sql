-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: 2171f2d0270a73b925955d869ff6f79c58b686da28d2da8e6785423c1aa1aedb
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
