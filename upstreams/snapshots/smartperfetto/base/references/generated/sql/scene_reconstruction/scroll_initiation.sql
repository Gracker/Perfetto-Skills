-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 59b4122937e29b04987a3c415c69cc1ce8120d970dcdd14b005ed5a34adbc22e

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
