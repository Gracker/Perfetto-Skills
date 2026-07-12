-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: e48c73408b2775bed099612d32832cde9f70ca33cd1cc462e0275b1454588359
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH
anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} AS start_ts,
    ${anr_ts} AS end_ts,
    ${timeout_ns} AS window_ns
),
main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (
      (${upid} > 0 AND p.upid = ${upid})
      OR (${upid} <= 0 AND ${pid} > 0 AND p.pid = ${pid}
          AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
      OR (${upid} <= 0 AND ${pid} <= 0
          AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
    )
    AND t.tid = p.pid
  LIMIT 1
),
main_states AS (
  SELECT
    ts.state,
    COALESCE(ts.io_wait, 0) AS io_wait,
    LOWER(COALESCE(ts.blocked_function, '')) AS blocked_function,
    MIN(CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END, aw.end_ts) - MAX(ts.ts, aw.start_ts) AS clipped_ns
  FROM thread_state ts
  JOIN main_thread mt ON ts.utid = mt.utid
  CROSS JOIN anr_window aw
  WHERE ts.ts < aw.end_ts
    AND (CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END) > aw.start_ts
),
metrics AS (
  SELECT
    COALESCE((SELECT SUM(clipped_ns) FROM main_states
      WHERE state IN ('S', 'D', 'I')
        AND (blocked_function GLOB '*binder*' OR blocked_function GLOB '*ipc*')), 0) AS binder_wait_ns,
    COALESCE((SELECT SUM(clipped_ns) FROM main_states
      WHERE state IN ('S', 'D', 'I')
        AND (blocked_function GLOB '*futex*' OR blocked_function GLOB '*mutex*'
             OR blocked_function GLOB '*monitor*' OR blocked_function GLOB '*rwsem*'
             OR blocked_function GLOB '*rwlock*')), 0) AS lock_wait_ns,
    COALESCE((SELECT SUM(clipped_ns) FROM main_states
      WHERE state IN ('D', 'DK')
        AND (
          io_wait = 1
          OR blocked_function GLOB '*io_schedule*'
          OR blocked_function GLOB '*filemap*'
          OR blocked_function GLOB '*do_page_fault*'
          OR blocked_function GLOB '*wait_on_page*'
          OR blocked_function GLOB '*folio_wait*'
          OR blocked_function GLOB '*fsync*'
          OR blocked_function GLOB '*submit_bio*'
          OR blocked_function GLOB '*blk*'
          OR blocked_function GLOB '*ext4*'
          OR blocked_function GLOB '*f2fs*'
          OR blocked_function GLOB '*erofs*'
          OR blocked_function GLOB '*ufshcd*'
          OR blocked_function GLOB '*mmc_*'
          OR blocked_function GLOB '*dm_*'
        )), 0) AS disk_wait_ns,
    COALESCE((SELECT SUM(clipped_ns) FROM main_states
      WHERE state IN ('D', 'DK')
        AND NOT (
          io_wait = 1
          OR blocked_function GLOB '*io_schedule*'
          OR blocked_function GLOB '*filemap*'
          OR blocked_function GLOB '*do_page_fault*'
          OR blocked_function GLOB '*wait_on_page*'
          OR blocked_function GLOB '*folio_wait*'
          OR blocked_function GLOB '*fsync*'
          OR blocked_function GLOB '*submit_bio*'
          OR blocked_function GLOB '*blk*'
          OR blocked_function GLOB '*ext4*'
          OR blocked_function GLOB '*f2fs*'
          OR blocked_function GLOB '*erofs*'
          OR blocked_function GLOB '*ufshcd*'
          OR blocked_function GLOB '*mmc_*'
          OR blocked_function GLOB '*dm_*'
        )), 0) AS uninterruptible_wait_ns,
    COALESCE((SELECT SUM(clipped_ns) FROM main_states
      WHERE state IN ('S', 'D', 'I')
        AND (blocked_function GLOB '*epoll*'
             OR blocked_function GLOB '*poll*'
             OR blocked_function GLOB '*do_epoll_wait*')), 0) AS poll_wait_ns,
    COALESCE((SELECT SUM(clipped_ns) FROM main_states
      WHERE state IN ('S', 'D', 'I')
        AND (blocked_function GLOB '*nanosleep*'
             OR blocked_function GLOB '*hrtimer*'
             OR blocked_function GLOB '*sleep*')), 0) AS sleep_wait_ns,
    COALESCE((SELECT SUM(clipped_ns) FROM main_states
      WHERE state IN ('R', 'R+')), 0) AS runnable_ns,
    COALESCE((SELECT SUM(clipped_ns) FROM main_states
      WHERE state = 'Running'), 0) AS running_ns,
    0 AS reserved_ns
),
candidates AS (
  SELECT 'binder_wait' AS direct_blocker_type, binder_wait_ns AS evidence_ns,
    'thread_state.blocked_function' AS evidence_source,
    CASE WHEN binder_wait_ns > 500000000 THEN 'high' ELSE 'medium' END AS confidence,
    'needs_peer_evidence' AS root_cause_boundary,
    '需要 Binder 对端进程/线程、server_dur 或 system_server 证据；不能只凭客户端等待定责' AS next_evidence_needed
  FROM metrics WHERE binder_wait_ns > 0
  UNION ALL
  SELECT 'lock_or_futex_wait', lock_wait_ns, 'thread_state.blocked_function',
    CASE WHEN lock_wait_ns > 500000000 THEN 'high' ELSE 'medium' END,
    'needs_lock_owner_evidence',
    '需要 monitor_contention/owner thread/锁链证据；普通 futex wait 只能说明候选锁等待'
  FROM metrics WHERE lock_wait_ns > 0
  UNION ALL
  SELECT 'disk_or_page_fault_io', disk_wait_ns, 'thread_state.io_wait_or_blocked_function',
    CASE WHEN disk_wait_ns > 500000000 THEN 'high' ELSE 'medium' END,
    'needs_io_system_context',
    '需要 iowait、blk/mmc、文件/DB slice 或系统 IO 压力交叉验证'
  FROM metrics WHERE disk_wait_ns > 0
  UNION ALL
  SELECT 'uninterruptible_wait', uninterruptible_wait_ns, 'thread_state.D_without_io_function',
    'low',
    'needs_kernel_wait_context',
    'D-state 只能说明不可中断等待；缺少 IO blocked_function 或 slice 证据时不能归因为磁盘/页缺失'
  FROM metrics WHERE uninterruptible_wait_ns > 0
  UNION ALL
  SELECT 'scheduler_pressure', runnable_ns, 'thread_state.R_or_R_plus',
    CASE WHEN runnable_ns * 100.0 / NULLIF((SELECT window_ns FROM anr_window), 0) > 30 THEN 'medium' ELSE 'low' END,
    'needs_system_load_context',
    '需要 CPU health、Top CPU process、sched latency 交叉验证'
  FROM metrics WHERE runnable_ns > 0
  UNION ALL
  SELECT 'cpu_busy_main_thread', running_ns, 'thread_state.Running',
    CASE WHEN running_ns * 100.0 / NULLIF((SELECT window_ns FROM anr_window), 0) > 70 THEN 'medium' ELSE 'low' END,
    'needs_hot_slice_context',
    '需要主线程热点 slice/调用栈确认是否业务计算，不能只凭 Running 定责'
  FROM metrics WHERE running_ns > 0
  UNION ALL
  SELECT 'native_poll_idle_or_ambiguous', poll_wait_ns, 'thread_state.blocked_function',
    'low',
    'not_root_cause_by_itself',
    'nativePoll/epoll 只说明当前快照等待消息；需 EventLog/Logcat/窗口焦点或系统压力补证'
  FROM metrics WHERE poll_wait_ns > 0
  UNION ALL
  SELECT 'main_thread_sleep', sleep_wait_ns, 'thread_state.blocked_function',
    CASE WHEN sleep_wait_ns > 500000000 THEN 'medium' ELSE 'low' END,
    'app_candidate_needs_stack_context',
    '需要 Thread.sleep/wait 调用栈确认是否业务设计问题'
  FROM metrics WHERE sleep_wait_ns > 0
  UNION ALL
  SELECT 'unknown', (SELECT window_ns FROM anr_window), 'no_direct_thread_state_or_slice_signal',
    'low',
    'unknown',
    '当前 Perfetto 表未给出直接阻塞点；需要 ANR trace/logcat/EventLog 或更完整采集'
  WHERE NOT EXISTS (
    SELECT 1 FROM metrics
    WHERE binder_wait_ns + lock_wait_ns + disk_wait_ns + uninterruptible_wait_ns
      + runnable_ns + running_ns + poll_wait_ns + sleep_wait_ns > 0
  )
)
SELECT
  direct_blocker_type,
  ROUND(evidence_ns / 1e6, 2) AS evidence_ms,
  ROUND(100.0 * evidence_ns / NULLIF((SELECT window_ns FROM anr_window), 0), 1) AS pct_of_timeout,
  evidence_source,
  confidence,
  root_cause_boundary,
  next_evidence_needed
FROM candidates
ORDER BY
  CASE confidence WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
  evidence_ns DESC
LIMIT 5
