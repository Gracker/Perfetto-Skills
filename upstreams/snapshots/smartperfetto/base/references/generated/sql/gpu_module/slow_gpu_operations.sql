-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: 192990c452ad55ead1e017ec97c29c577f607f5717020867e352b598e36abbce

SELECT
  slice.ts,
  slice.name AS operation,
  CAST(slice.dur / 1e6 AS REAL) AS dur_ms,
  thread.name AS thread_name
FROM slice
JOIN thread_track ON slice.track_id = thread_track.id
JOIN thread ON thread_track.utid = thread.utid
WHERE (slice.name LIKE '%draw%' OR slice.name LIKE '%flush%' OR slice.name LIKE '%eglSwap%')
  AND slice.dur > 5000000
ORDER BY slice.dur DESC
LIMIT 20
