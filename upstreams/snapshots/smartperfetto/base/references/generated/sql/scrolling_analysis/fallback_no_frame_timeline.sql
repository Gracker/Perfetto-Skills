-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 898b631aafbdad1f8c7fabc5e2a741fa750cf701ec82b9810adfd3e687b94431
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    )
      AND '${buffer_tx_coverage.data[0].target_process_status}' = 'not_found'
      THEN '⚠️ 目标进程不可用'
    ELSE '⚠️ 无法执行帧分析'
  END as status,
  CASE
    WHEN NOT EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    )
      THEN 'actual_frame_timeline_slice'
    WHEN '${buffer_tx_coverage.data[0].target_process_status}' = 'not_found'
      THEN '目标包: ${package}'
    ELSE '目标包 FrameTimeline / BufferTX 帧产出证据'
  END as missing_table,
  CASE
    WHEN NOT EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    )
      THEN '请确保 trace 采集时启用了 Frame Timeline (需要 Android 12+ 且开启 Choreographer tracing)'
    WHEN '${buffer_tx_coverage.data[0].target_process_status}' = 'not_found'
      THEN 'trace 未包含目标包进程；请确认包名，或在目标应用处于前台时重新采集。不能继续输出 FPS、掉帧率或根因'
    ELSE '已找到 FrameTimeline 表，但目标包无可用帧行，且 BufferTX 帧产出证据不足；不能输出 FPS、掉帧率或根因'
  END as suggestion
UNION ALL
SELECT
  'ℹ️ 可用替代方案' as status,
  'frame_slice (可用)' as missing_table,
  '可尝试使用 frame_slice 进行基础帧耗时分析' as suggestion
WHERE EXISTS (
    SELECT 1 FROM sqlite_master
    WHERE type = 'table' AND name = 'frame_slice'
  )
  AND NOT (
    EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type = 'table' AND name = 'actual_frame_timeline_slice'
    )
    AND '${buffer_tx_coverage.data[0].target_process_status}' = 'not_found'
  )
