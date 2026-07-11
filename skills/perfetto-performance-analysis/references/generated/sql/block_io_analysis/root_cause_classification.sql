-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/block_io_analysis.skill.yaml
-- Source SHA-256: 6694949cda0a83aa4448782fcdc7b6b7fb8c62134598018d5f702eb571a23985
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH io_stats AS (
  SELECT
    COALESCE(MAX(slice.dur) / 1e6, 0) AS max_io_ms,
    COALESCE(AVG(slice.dur) / 1e6, 0) AS avg_io_ms,
    COUNT(*) AS total_io_count
  FROM slice
  JOIN track ON slice.track_id = track.id
  WHERE track.type = 'block_io'
    AND (${start_ts} IS NULL OR slice.ts + slice.dur > ${start_ts})
    AND (${end_ts} IS NULL OR slice.ts < ${end_ts})
),
queue_stats AS (
  SELECT
    COALESCE(MAX(ops_in_queue_or_device), 0) AS max_queue,
    COALESCE(AVG(ops_in_queue_or_device), 0) AS avg_queue
  FROM linux_active_block_io_operations_by_device
  WHERE (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
blocking_stats AS (
  SELECT
    COALESCE(SUM(CASE WHEN t.tid = p.pid THEN ts.dur ELSE 0 END) / 1e6, 0) AS main_thread_blocked_ms,
    COALESCE(SUM(ts.dur) / 1e6, 0) AS total_blocked_ms,
    COUNT(DISTINCT CASE WHEN t.tid = p.pid THEN t.utid END) AS main_thread_blocked_count
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  LEFT JOIN process p ON t.upid = p.upid
  WHERE ts.state IN ('D', 'DK')
    AND (
      COALESCE(ts.io_wait, 0) = 1
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%filemap%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%page_fault%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%wait_on_page%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%folio_wait%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%io_schedule%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%submit_bio%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%sync%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%blk_%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%ext4%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%f2fs%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%erofs%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%ufshcd%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%mmc_%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%dm_%'
    )
    AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
),
device_stats AS (
  SELECT
    extract_arg(track.dimension_arg_set_id, 'block_device') AS dev,
    ROUND(AVG(slice.dur) / 1e6, 2) AS dev_avg_ms,
    ROUND(MAX(slice.dur) / 1e6, 2) AS dev_max_ms
  FROM slice
  JOIN track ON slice.track_id = track.id
  WHERE track.type = 'block_io'
    AND (${start_ts} IS NULL OR slice.ts + slice.dur > ${start_ts})
    AND (${end_ts} IS NULL OR slice.ts < ${end_ts})
  GROUP BY dev
  ORDER BY dev_avg_ms DESC
  LIMIT 1
)
SELECT * FROM (
  -- IO_BOTTLENECK: 高队列深度 + 慢 IO
  SELECT
    'IO_BOTTLENECK' AS category,
    'critical' AS severity,
    'IO 瓶颈：队列积压严重且 IO 耗时高' AS description,
    '最大队列深度 ' || CAST(CAST(q.max_queue AS INTEGER) AS TEXT)
      || '，平均 IO 耗时 ' || CAST(ROUND(i.avg_io_ms, 1) AS TEXT) || 'ms'
      || '，最大 IO 耗时 ' || CAST(ROUND(i.max_io_ms, 1) AS TEXT) || 'ms' AS evidence
  FROM io_stats i, queue_stats q
  WHERE q.max_queue > 32 AND i.avg_io_ms > 10

  UNION ALL

  -- IO_MAIN_THREAD_BLOCK: 主线程 D/DK 且有 io_wait 或 IO/page-cache blocked_function
  SELECT
    'IO_MAIN_THREAD_BLOCK' AS category,
    'critical' AS severity,
    '主线程出现 IO/page-cache 等待候选，影响 UI 响应' AS description,
    '主线程 IO/page-cache 等待候选总时间 ' || CAST(ROUND(b.main_thread_blocked_ms, 1) AS TEXT) || 'ms' AS evidence
  FROM blocking_stats b
  WHERE b.main_thread_blocked_ms > 50

  UNION ALL

  -- IO_SLOW_DEVICE: 特定设备慢
  SELECT
    'IO_SLOW_DEVICE' AS category,
    'warning' AS severity,
    '设备 ' || COALESCE(d.dev, 'unknown') || ' IO 性能较差' AS description,
    '平均 IO 耗时 ' || CAST(d.dev_avg_ms AS TEXT) || 'ms'
      || '，最大 ' || CAST(d.dev_max_ms AS TEXT) || 'ms' AS evidence
  FROM device_stats d
  WHERE d.dev_avg_ms > 20

  UNION ALL

  -- IO_QUEUE_PRESSURE: 队列深度高但 IO 速度尚可
  SELECT
    'IO_QUEUE_PRESSURE' AS category,
    'warning' AS severity,
    'IO 队列积压，存在并发 IO 压力' AS description,
    '最大队列深度 ' || CAST(CAST(q.max_queue AS INTEGER) AS TEXT)
      || '，平均队列深度 ' || CAST(ROUND(q.avg_queue, 1) AS TEXT) AS evidence
  FROM queue_stats q, io_stats i
  WHERE q.max_queue > 32 AND i.avg_io_ms <= 10

  UNION ALL

  -- IO_NORMAL: 正常
  SELECT
    'IO_NORMAL' AS category,
    'info' AS severity,
    'IO 性能正常' AS description,
    '总 IO 操作 ' || CAST(i.total_io_count AS TEXT) || ' 次'
      || '，平均耗时 ' || CAST(ROUND(i.avg_io_ms, 1) AS TEXT) || 'ms'
      || '，最大队列深度 ' || CAST(CAST(q.max_queue AS INTEGER) AS TEXT) AS evidence
  FROM io_stats i, queue_stats q
  WHERE q.max_queue <= 32 AND i.avg_io_ms <= 10
)
ORDER BY CASE severity
  WHEN 'critical' THEN 1
  WHEN 'warning' THEN 2
  WHEN 'info' THEN 3
END
