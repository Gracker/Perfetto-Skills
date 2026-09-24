-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 2dc3194fd8730e6ce16c5d4db97860cc8cdfccee8b6b2f23dfd11ddb3d752ab4
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

SELECT printf('%d', s.ts) AS ts, printf('%d', s.dur) AS dur,
  'RecyclerView 滚动处理' AS event, s.id AS gesture_id, p.name AS app_package,
  'scroll_processing' AS event_type, 'scroll_start' AS category,
  'RecyclerView RV Scroll 标记；不据此推断手势开始时间' AS explanation,
  'slice' AS source_table, CAST(s.id AS TEXT) AS source_id,
  t.upid, s.track_id, 'observed' AS source_status, COUNT(*) OVER () AS total_rows
FROM slice s JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON t.utid = tt.utid JOIN process p ON p.upid = t.upid
WHERE s.name = 'RV Scroll' AND s.dur >= 0 AND t.is_main_thread = 1
ORDER BY s.ts
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)
