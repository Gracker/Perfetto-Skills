-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/anr_main_thread_blocking.skill.yaml
-- Source SHA-256: e19ece9595a2bf2bd22ead9b8e4c2236e061a672b7f6e76c0c5cd4cf94478349
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

-- 使用 stdlib android_binder_txns 替代手动 binder slice 解析
WITH analysis_window AS (
  SELECT
    COALESCE(${start_ts},
      CASE WHEN ${anr_ts} IS NOT NULL THEN ${anr_ts} - 5000000000 ELSE NULL END,
      (SELECT MIN(ts) FROM slice)
    ) as w_start,
    COALESCE(${end_ts},
      CASE WHEN ${anr_ts} IS NOT NULL THEN ${anr_ts} + 1000000000 ELSE NULL END,
      (SELECT MAX(ts + dur) FROM slice)
    ) as w_end
)
SELECT
  printf('%d', bt.client_ts) as ts,
  COALESCE(bt.aidl_name, 'binder transaction') as slice_name,
  ROUND(bt.client_dur / 1e6, 2) as dur_ms,
  bt.server_process,
  bt.server_thread
FROM android_binder_txns bt
CROSS JOIN analysis_window aw
WHERE bt.is_main_thread = 1
  AND bt.is_sync = 1
  AND bt.client_upid = (
    SELECT p.upid FROM process p
    WHERE '${process_name}' != '' AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
    LIMIT 1
  )
  AND bt.client_ts >= aw.w_start
  AND bt.client_ts + bt.client_dur <= aw.w_end
ORDER BY bt.client_dur DESC
LIMIT 20
