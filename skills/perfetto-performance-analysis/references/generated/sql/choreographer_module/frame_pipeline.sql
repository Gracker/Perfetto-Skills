-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/choreographer_module.skill.yaml
-- Source SHA-256: 4a35f45abe4b7e038dbbcded10d22da6cb28b79dbd7a66e0e9d83452c778e916
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  s.name AS pipeline_stage,
  COUNT(*) AS count,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name LIKE '%${package}%'
  AND (s.name GLOB '*dequeueBuffer*'
       OR s.name GLOB '*queueBuffer*'
       OR s.name GLOB '*acquireBuffer*'
       OR s.name GLOB '*eglSwapBuffers*'
       OR s.name GLOB '*syncFrameState*'
       OR s.name GLOB '*DrawFrame*')
GROUP BY s.name
ORDER BY avg_ms DESC
LIMIT 10
