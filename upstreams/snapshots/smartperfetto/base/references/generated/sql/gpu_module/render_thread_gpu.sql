-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: b886833bb0a8ce73f11e481eb087092418db60082fdec57dda4d24dd6c000658

SELECT
  thread.name AS thread_name,
  CAST(SUM(slice.dur) / 1e6 AS REAL) AS total_gpu_ms,
  COUNT(*) AS gpu_calls,
  CAST(AVG(slice.dur) / 1e6 AS REAL) AS avg_gpu_ms,
  CAST(MAX(slice.dur) / 1e6 AS REAL) AS max_gpu_ms
FROM slice
JOIN thread_track ON slice.track_id = thread_track.id
JOIN thread ON thread_track.utid = thread.utid
WHERE thread.name = 'RenderThread'
  AND (slice.name LIKE '%draw%' OR slice.name LIKE '%flush%' OR slice.name LIKE '%swap%')
GROUP BY thread.name
