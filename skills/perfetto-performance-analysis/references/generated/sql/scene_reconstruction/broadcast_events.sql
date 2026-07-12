-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

SELECT
  printf('%d', s.ts) AS ts,
  CASE
    WHEN s.name LIKE '%:%' THEN SUBSTR(s.name, INSTR(s.name, ':') + 1)
    WHEN s.name LIKE '% %' THEN SUBSTR(s.name, INSTR(s.name, ' ') + 1)
    ELSE p.name
  END AS receiver_name,
  CASE
    WHEN s.name GLOB '*BroadcastQueue*' THEN 'BroadcastQueue'
    WHEN s.name GLOB '*broadcastReceive*' THEN 'broadcastReceive'
    WHEN s.name GLOB '*AlarmManager*' THEN 'AlarmManager'
    ELSE s.name
  END AS broadcast_action,
  ROUND(s.dur / 1e6, 1) AS dur_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (
  s.name GLOB '*BroadcastQueue*'
  OR s.name GLOB '*broadcastReceive*'
  OR s.name GLOB '*AlarmManager*'
)
  AND s.dur > 1000000
ORDER BY s.ts
LIMIT 200
