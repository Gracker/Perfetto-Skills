-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: 39751b02d647c86152142d1d75ba69d8b950f6ea97c884c16908e3696104804b

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
