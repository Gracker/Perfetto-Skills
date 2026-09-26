-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/io_pressure.skill.yaml
-- Source SHA-256: 376ae3d00765275d36e436290949e64c85af55dccfe476e25630487f4b50c2bb
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- No input CTE. The kernel wait-channel (thread_state.blocked_function) families
-- that name file, page-cache or block I/O. Consumers test a lower-cased
-- blocked_function against every pattern:
--   EXISTS (SELECT 1 FROM io_blocked_function_families f
--           WHERE LOWER(COALESCE(ts.blocked_function, '')) GLOB f.pattern)
--
-- GLOB, not LIKE: in LIKE `_` is a one-character wildcard, so '%dm_%' also
-- matched 'dma_fence_wait_timeout' and booked GPU fence waits (D state, common
-- on RenderThread and SurfaceFlinger) as I/O; '%blk_%' and '%mmc_%' were
-- looser than written for the same reason. GLOB reads `_` literally and is
-- case-sensitive, hence the LOWER() on the consumer side.
--
-- blocked_function is a single-frame wchan, emitted by sched_blocked_reason for
-- D-state waits only. A match is an I/O candidate that still needs file,
-- page-fault or block-layer evidence; it is not proof of an I/O root cause.
io_blocked_function_families(pattern) AS (
  VALUES
    ('*io_schedule*'),
    ('*wait_on_page*'),
    ('*folio_wait*'),
    ('*wait_on_buffer*'),
    ('*submit_bio*'),
    ('*filemap*'),
    ('*page_fault*'),
    ('*ext4*'),
    ('*f2fs*'),
    ('*erofs*'),
    ('*blk_*'),
    ('*dm_*'),
    ('*mmc_*'),
    ('*ufshcd*')
)
,
io_wait_states AS (
  SELECT
    ts.utid, ts.ts, ts.dur, ts.state,
    ts.blocked_function,
    ts.io_wait
  FROM thread_state ts
  WHERE ts.state IN ('D', 'DK')
    AND (
      COALESCE(ts.io_wait, 0) = 1
      OR EXISTS (SELECT 1 FROM io_blocked_function_families f WHERE LOWER(COALESCE(ts.blocked_function, '')) GLOB f.pattern)
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
