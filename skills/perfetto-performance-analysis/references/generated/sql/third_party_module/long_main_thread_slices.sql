-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: 4ec1adf4fca9bc5c1c99e0f926c86d6b2effc9f0f47b5f20451dda2bc4807ad5
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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
  AND process.name LIKE '%${package}%'
  AND slice.dur > 5000000
  AND slice.depth < 3
ORDER BY slice.dur DESC
LIMIT 30
