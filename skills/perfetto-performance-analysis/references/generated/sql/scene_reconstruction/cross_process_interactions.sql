-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

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
LIMIT 100
