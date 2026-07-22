-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: 6dd740df9f3de46527f96908cf6ac30d71767e6f61d2bc2d6544f825cbbc3551
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

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
