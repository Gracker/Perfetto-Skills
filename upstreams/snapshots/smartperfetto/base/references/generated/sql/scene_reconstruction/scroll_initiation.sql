-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 8832b9e9b6f0bb86a0676bcd50f367546a3406ef8111be90fe60511d26678d5b
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

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
