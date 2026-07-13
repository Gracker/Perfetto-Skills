-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_main_thread_states_in_range.skill.yaml
-- Source SHA-256: e80f0fec172c222ce015de035a53406369f359dc9a4bd41bf913b7104344b333
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

WITH state_rows AS (
  SELECT
    s.startup_id,
    s.dur AS startup_dur,
    ts.state,
    COALESCE(ts.io_wait, 0) AS io_wait,
    COALESCE(NULLIF(ts.blocked_function, ''), '-') AS blocked_function,
    LOWER(COALESCE(ts.blocked_function, '')) AS blocked_function_lc,
    MIN(CASE WHEN ts.dur < 0 THEN s.ts + s.dur ELSE ts.ts + ts.dur END, s.ts + s.dur) - MAX(ts.ts, s.ts) AS clipped_dur
  FROM thread_state ts
  JOIN android_startup_threads st ON ts.utid = st.utid
  JOIN android_startups s ON st.startup_id = s.startup_id
  WHERE st.is_main_thread = 1
    AND (s.package GLOB '${package}*' OR '${package}' = '')
    AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
    AND ts.ts < s.ts + s.dur
    AND (CASE WHEN ts.dur < 0 THEN s.ts + s.dur ELSE ts.ts + ts.dur END) > s.ts
)
SELECT
  state,
  CASE state
    WHEN 'Running' THEN 'Running (CPU执行)'
    WHEN 'R' THEN 'Runnable (等待调度)'
    WHEN 'R+' THEN 'Runnable+ (抢占等待)'
    WHEN 'S' THEN 'Sleeping (可中断睡眠/等待)'
    WHEN 'D' THEN CASE WHEN io_wait = 1 THEN 'Uninterruptible sleep (io_wait)' ELSE 'Uninterruptible sleep (不可中断等待)' END
    WHEN 'DK' THEN CASE WHEN io_wait = 1 THEN 'Uninterruptible sleep (kernel io_wait)' ELSE 'Uninterruptible sleep (kernel wait)' END
    ELSE state
  END as state_desc,
  ROUND(SUM(clipped_dur) / 1e6, 2) as total_dur_ms,
  ROUND(100.0 * SUM(clipped_dur) / NULLIF(MAX(startup_dur), 0), 1) as percent,
  COUNT(*) as count,
  io_wait,
  CASE
    WHEN state IN ('D', 'DK') AND io_wait = 1 THEN 'direct_io_wait'
    WHEN state IN ('D', 'DK') AND (
      blocked_function_lc LIKE '%filemap%'
      OR blocked_function_lc LIKE '%page_fault%'
      OR blocked_function_lc LIKE '%wait_on_page%'
      OR blocked_function_lc LIKE '%folio_wait%'
      OR blocked_function_lc LIKE '%io_schedule%'
      OR blocked_function_lc LIKE '%submit_bio%'
      OR blocked_function_lc LIKE '%blk_%'
      OR blocked_function_lc LIKE '%ext4%'
      OR blocked_function_lc LIKE '%f2fs%'
      OR blocked_function_lc LIKE '%erofs%'
      OR blocked_function_lc LIKE '%ufshcd%'
      OR blocked_function_lc LIKE '%mmc_%'
      OR blocked_function_lc LIKE '%dm_%'
    ) THEN 'inferred_io_or_page_cache'
    WHEN state IN ('D', 'DK') THEN 'ambiguous_uninterruptible_wait'
    WHEN state = 'S' AND (blocked_function_lc LIKE '%epoll%' OR blocked_function_lc LIKE '%poll%') THEN 'poll_idle_or_ambiguous'
    WHEN state = 'S' AND (blocked_function_lc LIKE '%futex%' OR blocked_function_lc LIKE '%mutex%' OR blocked_function_lc LIKE '%monitor%') THEN 'lock_wait'
    WHEN blocked_function_lc LIKE '%binder%' THEN 'binder_wait'
    ELSE 'state_only'
  END as evidence_strength,
  blocked_function as blocked_functions
FROM state_rows
WHERE clipped_dur > 0
GROUP BY startup_id, state, io_wait, blocked_function
ORDER BY total_dur_ms DESC
