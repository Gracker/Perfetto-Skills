-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: 4554575145483d31969e45a7f620e2babcd548a6287d30687a303389845885bd
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

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
