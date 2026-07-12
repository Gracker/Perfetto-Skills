-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: d005054dab0e8c6ea08c377ca3407e935fb7134f30aa318211845cf32f3e2a0a
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  bt.server_process,
  bt.aidl_name,
  bt.client_dur / 1e6 as binder_dur_ms,
  -- 关联帧信息（如果可用）
  af.frame_id,
  af.dur / 1e6 as frame_dur_ms,
  -- 判断是否在帧期间
  CASE WHEN af.frame_id IS NOT NULL THEN '帧内' ELSE '帧外' END as in_frame
FROM android_binder_txns bt
LEFT JOIN android_frames af ON (
  bt.client_ts >= af.ts
  AND bt.client_ts < af.ts + af.dur
  AND af.upid = (
    SELECT upid FROM process WHERE name = '${target_process.data[0].process_name}' LIMIT 1
  )
)
WHERE bt.client_process = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
  AND bt.is_main_thread = 1
  AND bt.client_dur > 1000000  -- > 1ms
ORDER BY bt.client_dur DESC
LIMIT 20
