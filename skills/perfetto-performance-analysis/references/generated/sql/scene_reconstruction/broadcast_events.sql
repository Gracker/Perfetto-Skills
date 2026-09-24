-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 2dc3194fd8730e6ce16c5d4db97860cc8cdfccee8b6b2f23dfd11ddb3d752ab4
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

SELECT scene_rows.*, COUNT(*) OVER () AS total_rows FROM (
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
) AS scene_rows
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)
