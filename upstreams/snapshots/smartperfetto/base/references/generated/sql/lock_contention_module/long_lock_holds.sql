-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: d15f42c14eb71e09519f090b9772b4fbb26420601c470115a36e8ce058c804e3

SELECT
  s.ts,
  s.name AS lock_operation,
  CAST(s.dur / 1e6 AS REAL) AS hold_ms,
  t.name AS holder_thread,
  t.tid AS holder_tid
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND (s.name GLOB '*holding*lock*'
       OR s.name GLOB '*acquired*'
       OR s.name GLOB '*lock*held*'
       OR (s.name GLOB '*synchronized*' AND s.dur > 5000000))
  AND s.dur > 5000000  -- > 5ms
ORDER BY s.dur DESC
LIMIT 15
