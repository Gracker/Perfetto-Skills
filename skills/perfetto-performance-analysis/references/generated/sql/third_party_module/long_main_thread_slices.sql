-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: dacb92b3b21e6a6eb465c54481840390078de91ffe280ccb2ee14d978360ae96
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

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
