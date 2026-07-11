-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/main_thread_states_in_range.skill.yaml
-- Source SHA-256: 9dff50424647c05fa5494e804e49bc18338d552e3b39edb6edca6cbb4c53e3e2
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (
      (${upid|0} > 0 AND p.upid = ${upid|0})
      OR (${upid|0} <= 0 AND ${pid|0} > 0 AND p.pid = ${pid|0}
          AND ('${package|}' = '' OR p.name = '${package|}' OR p.name GLOB '${package|}:*'))
      OR (${upid|0} <= 0 AND ${pid|0} <= 0
          AND ('${package|}' = '' OR p.name = '${package|}' OR p.name GLOB '${package|}:*'))
    )
    AND t.tid = p.pid
  LIMIT 1
)
SELECT
  ts.state,
  CASE ts.state
    WHEN 'Running' THEN 'Running (CPU执行)'
    WHEN 'R' THEN 'Runnable (等待调度)'
    WHEN 'R+' THEN 'Runnable+ (抢占等待)'
    WHEN 'S' THEN 'Sleeping (主动睡眠)'
    WHEN 'D' THEN 'Uninterruptible sleep (不可中断等待)'
    WHEN 'I' THEN 'Idle (空闲)'
    ELSE ts.state
  END as state_desc,
  COALESCE(NULLIF(ts.blocked_function, ''), '-') as blocked_function,
  COALESCE(ts.io_wait, 0) as io_wait,
  CASE
    WHEN ts.state IN ('D', 'DK') AND COALESCE(ts.io_wait, 0) = 1 THEN 'direct_io_wait'
    WHEN ts.state IN ('D', 'DK') AND (
      LOWER(COALESCE(ts.blocked_function, '')) LIKE '%filemap%'
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
    ) THEN 'inferred_io_or_page_cache'
    WHEN ts.state IN ('D', 'DK') THEN 'ambiguous_uninterruptible_wait'
    WHEN ts.state = 'S' AND (LOWER(COALESCE(ts.blocked_function, '')) LIKE '%epoll%' OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%poll%') THEN 'poll_idle_or_ambiguous'
    WHEN ts.state = 'S' AND (LOWER(COALESCE(ts.blocked_function, '')) LIKE '%futex%' OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%mutex%' OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%monitor%') THEN 'lock_wait'
    WHEN LOWER(COALESCE(ts.blocked_function, '')) LIKE '%binder%' THEN 'binder_wait'
    ELSE 'state_only'
  END as evidence_strength,
  ROUND(SUM(
    MIN(CASE WHEN ts.dur < 0 THEN ${end_ts} ELSE ts.ts + ts.dur END, ${end_ts}) - MAX(ts.ts, ${start_ts})
  ) / 1e6, 2) as total_dur_ms,
  ROUND(100.0 * SUM(
    MIN(CASE WHEN ts.dur < 0 THEN ${end_ts} ELSE ts.ts + ts.dur END, ${end_ts}) - MAX(ts.ts, ${start_ts})
  ) / NULLIF(${end_ts} - ${start_ts}, 0), 1) as pct,
  COUNT(*) as count
FROM thread_state ts
JOIN main_thread mt ON ts.utid = mt.utid
WHERE ts.ts < ${end_ts}
  AND (CASE WHEN ts.dur < 0 THEN ${end_ts} ELSE ts.ts + ts.dur END) > ${start_ts}
GROUP BY ts.state, COALESCE(ts.io_wait, 0), ts.blocked_function
ORDER BY total_dur_ms DESC
LIMIT ${top_k|10}
