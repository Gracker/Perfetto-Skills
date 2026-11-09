-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: b886833bb0a8ce73f11e481eb087092418db60082fdec57dda4d24dd6c000658

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
