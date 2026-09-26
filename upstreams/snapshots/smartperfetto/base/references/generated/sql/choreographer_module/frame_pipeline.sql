-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/choreographer_module.skill.yaml
-- Source SHA-256: 89db8f840e3ef0967b9ba9b94d1588c0479509358a203e9b2a8eb37910fc7509
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  s.name AS pipeline_stage,
  COUNT(*) AS count,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND (s.name GLOB '*dequeueBuffer*'
       OR s.name GLOB '*queueBuffer*'
       OR s.name GLOB '*acquireBuffer*'
       OR s.name GLOB '*eglSwapBuffers*'
       OR s.name GLOB '*syncFrameState*'
       OR s.name GLOB '*DrawFrame*')
GROUP BY s.name
ORDER BY avg_ms DESC
LIMIT 10
