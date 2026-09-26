-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 2dc3194fd8730e6ce16c5d4db97860cc8cdfccee8b6b2f23dfd11ddb3d752ab4
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
