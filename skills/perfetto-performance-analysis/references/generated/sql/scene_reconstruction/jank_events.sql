-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 8832b9e9b6f0bb86a0676bcd50f367546a3406ef8111be90fe60511d26678d5b
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT scene_rows.*, COUNT(*) OVER () AS total_rows FROM (
SELECT
  printf('%d', ts) AS ts,
  printf('%d', dur) AS dur,
  CASE
    WHEN jank_type LIKE '%App Deadline%' OR jank_type = 'Self Jank' THEN 'App掉帧'
    WHEN jank_type LIKE '%SurfaceFlinger%' THEN '合成器掉帧'
    WHEN jank_type LIKE '%Buffer Stuffing%' THEN '缓冲区积压'
    ELSE '掉帧'
  END ||
  CASE jank_severity_type
    WHEN 'Partial' THEN ' (轻微)'
    WHEN 'Full' THEN ' (严重)'
    ELSE ''
  END ||
  ' [' || CAST(dur / 1000000 AS INT) || 'ms]' AS event,
  jank_type,
  jank_severity_type,
  'performance' AS category
FROM actual_frame_timeline_slice
WHERE jank_type IS NOT NULL
  AND jank_type != 'None'
  AND jank_type != ''
ORDER BY ts
) AS scene_rows
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)
