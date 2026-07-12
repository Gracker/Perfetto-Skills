-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/io_pressure.skill.yaml
-- Source SHA-256: 4799f46bab6741b4894853f4a43ace14682cc8fff4ebdcb8cfc01e9c3606f571
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH io_wait_states AS (
  SELECT
    ts.utid, ts.ts, ts.dur, ts.state,
    ts.blocked_function,
    ts.io_wait
  FROM thread_state ts
  WHERE ts.state IN ('D', 'DK')
    AND (
      COALESCE(ts.io_wait, 0) = 1
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%filemap%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%page_fault%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%wait_on_page%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%folio_wait%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%io_schedule%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%submit_bio%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%blk_%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%ext4%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%f2fs%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%erofs%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%ufshcd%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%mmc_%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%dm_%'
    )
    AND ts.dur > ${min_duration_ms|1} * 1e6
    AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
),
category_stats AS (
  SELECT
    CASE
      WHEN blocked_function LIKE '%f2fs%' OR blocked_function LIKE '%ext4%' THEN 'filesystem'
      WHEN blocked_function LIKE '%read%' OR blocked_function LIKE '%write%' THEN 'read_write'
      WHEN blocked_function LIKE '%sync%' OR blocked_function LIKE '%fsync%' THEN 'sync'
      WHEN blocked_function LIKE '%blk%' OR blocked_function LIKE '%mmc%' OR blocked_function LIKE '%ufs%' THEN 'block_device'
      WHEN blocked_function IS NULL OR blocked_function = '' THEN 'unclassified'
      ELSE 'other'
    END as category,
    SUM(dur) / 1e6 as total_ms,
    COUNT(*) as event_count
  FROM io_wait_states
  GROUP BY category
),
total AS (
  SELECT SUM(total_ms) as grand_total_ms FROM category_stats
),
dominant AS (
  SELECT category, total_ms,
    ROUND(100.0 * total_ms / NULLIF((SELECT grand_total_ms FROM total), 0), 1) as pct
  FROM category_stats
  ORDER BY total_ms DESC
  LIMIT 1
)
SELECT
  (SELECT grand_total_ms FROM total) as total_io_ms,
  (SELECT category FROM dominant) as primary_category,
  (SELECT pct FROM dominant) as primary_pct,
  CASE
    WHEN (SELECT grand_total_ms FROM total) > ${critical_io_wait_ms|5000} THEN 'critical'
    WHEN (SELECT grand_total_ms FROM total) > ${warning_io_wait_ms|1000} THEN 'warning'
    WHEN (SELECT grand_total_ms FROM total) > 100 THEN 'info'
    ELSE 'normal'
  END as severity,
  CASE
    WHEN (SELECT category FROM dominant) = 'filesystem' THEN 'IO_FS_BOUND'
    WHEN (SELECT category FROM dominant) = 'sync' THEN 'IO_SYNC_BOUND'
    WHEN (SELECT category FROM dominant) = 'block_device' THEN 'IO_DEVICE_BOUND'
    WHEN (SELECT category FROM dominant) = 'read_write' THEN 'IO_RW_BOUND'
    ELSE 'IO_MIXED'
  END as root_cause_type,
  CASE
    WHEN (SELECT category FROM dominant) = 'filesystem'
      THEN '文件系统操作是主要 IO 瓶颈 (' || (SELECT pct FROM dominant) || '%)，建议优化文件读写或使用异步 IO'
    WHEN (SELECT category FROM dominant) = 'sync'
      THEN '同步操作是主要瓶颈 (' || (SELECT pct FROM dominant) || '%)，考虑减少 fsync/sync 调用'
    WHEN (SELECT category FROM dominant) = 'block_device'
      THEN '块设备 IO 是主要瓶颈 (' || (SELECT pct FROM dominant) || '%)，可能存储设备性能不足'
    WHEN (SELECT category FROM dominant) = 'read_write'
      THEN '读写操作是主要瓶颈 (' || (SELECT pct FROM dominant) || '%)，考虑使用缓存或异步读写'
    ELSE 'IO 等待来源分散，需要综合优化'
  END as suggestion
