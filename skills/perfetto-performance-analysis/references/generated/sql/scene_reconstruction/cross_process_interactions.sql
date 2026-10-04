-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 59b4122937e29b04987a3c415c69cc1ce8120d970dcdd14b005ed5a34adbc22e

SELECT scene_rows.*, COUNT(*) OVER () AS total_rows FROM (
-- 使用 stdlib android_binder_txns 替代手动 7-table JOIN
SELECT
  printf('%d', bt.client_ts) AS ts,
  bt.client_process,
  bt.server_process,
  ROUND(bt.client_dur / 1e6, 1) AS dur_ms,
  COALESCE(bt.aidl_name, 'binder transaction') AS interface_name
FROM android_binder_txns bt
WHERE bt.client_dur > 10000000
  AND bt.client_process IS NOT NULL
  AND bt.server_process IS NOT NULL
  AND bt.client_process != bt.server_process
ORDER BY bt.client_dur DESC
) AS scene_rows
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)
