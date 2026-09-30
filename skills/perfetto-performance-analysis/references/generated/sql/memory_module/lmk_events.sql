-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: c4d29f5ee21c06081cc03ddeefcc79718e488db294e4623000e124ce9c292f0b

SELECT
  s.ts,
  s.name AS lmk_event,
  CAST(s.dur / 1e6 AS REAL) AS dur_ms,
  t.name AS thread_name
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
WHERE s.name GLOB '*lmk*'
  OR s.name GLOB '*LMK*'
  OR s.name GLOB '*lowmemory*'
  OR s.name GLOB '*oom*'
  OR s.name GLOB '*OOM*'
  OR s.name GLOB '*kill*memory*'
ORDER BY s.ts DESC
LIMIT 30
