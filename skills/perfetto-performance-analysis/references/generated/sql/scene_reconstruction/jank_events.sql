-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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
LIMIT 200
