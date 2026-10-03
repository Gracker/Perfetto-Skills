-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: 579fe2d70ef30c53d7a5e32a06732ef2872ce8b45c31aea88cb079bf2a45c9e0

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
