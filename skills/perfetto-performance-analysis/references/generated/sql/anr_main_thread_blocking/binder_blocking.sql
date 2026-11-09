-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/anr_main_thread_blocking.skill.yaml
-- Source SHA-256: 125f6c0f585e4fb4e02d376ddf8c103f5229e42fbdff3be9b176133960f18834

-- 使用 stdlib android_binder_txns 替代手动 binder slice 解析
SELECT
  printf('%d', bt.client_ts) as ts,
  COALESCE(bt.aidl_name, 'binder transaction') as slice_name,
  ROUND(bt.client_dur / 1e6, 2) as dur_ms,
  bt.server_process,
  bt.server_thread,
  printf('%d', bt.client_ts + bt.client_dur) as end_ts,
  bt.client_dur as dur_ns,
  bt.client_upid as upid,
  CASE WHEN bt.client_dur > 0 THEN 'observed' ELSE 'unavailable' END as wait_evidence
FROM android_binder_txns bt
WHERE bt.is_main_thread = 1
  AND bt.is_sync = 1
  AND bt.client_upid = (
    SELECT p.upid FROM process p
    WHERE '${process_name}' != '' AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
    LIMIT 1
  )
  AND bt.client_ts >= ${analysis_window.data[0].start_ts|NULL}
  AND bt.client_ts + bt.client_dur <= ${analysis_window.data[0].end_ts|NULL}
ORDER BY bt.client_dur DESC
LIMIT 20
