-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 7c73e3893771fc262f7afad100bd5963d65ee2afe54b8bd139a0cf95e9c82eb8
-- Source commit: e198ac39082cf1b029b0833e46e8ee49dd9387ce

SELECT
  CASE
    WHEN ${__process_scope.upid} IS NOT NULL THEN 'unavailable_exact_upid'
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
      THEN 'trace 未包含目标包进程；请确认包名，或在目标应用处于前台时重新采集。不能输出该目标的帧指标或任务结论'
    ELSE '已找到 FrameTimeline 表，但目标包无可用帧行，且 BufferTX 帧产出证据不足；不能输出 FPS、掉帧率或帧根因；仍可读取实际主线程任务与状态证据'
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
