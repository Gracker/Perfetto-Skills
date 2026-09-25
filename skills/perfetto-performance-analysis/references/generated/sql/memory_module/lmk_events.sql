-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: 414d1472ca7ef5f999ad8066cb1322622316c622e4bb29e5d0ce7f7b0e4fad9b
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
