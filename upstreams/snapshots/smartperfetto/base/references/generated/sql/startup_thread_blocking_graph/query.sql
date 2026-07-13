-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_thread_blocking_graph.skill.yaml
-- Source SHA-256: efc99dd7288f62ffa136feb19c852594d545620e9a17523b1070b71f14041d67
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH process_threads AS (
  SELECT
    t.utid,
    t.tid,
    t.name as thread_name,
    p.pid,
    CASE
      WHEN t.tid = p.pid THEN 'main'
      WHEN t.name = 'RenderThread' THEN 'render'
      WHEN t.name GLOB '*HeapTaskDaemon*' OR t.name GLOB '*FinalizerDaemon*' THEN 'gc'
      WHEN t.name GLOB 'Jit thread pool*' THEN 'jit'
      WHEN t.name GLOB 'Binder:*' THEN 'binder'
      ELSE 'other'
    END as role
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*'
),
-- 查找所有阻塞事件（S/D 状态 > min_block_ms）及其唤醒者
blocking_events AS (
  SELECT
    pt.thread_name as blocked_thread,
    pt.role as blocked_role,
    ts.state as blocked_state,
    ts.blocked_function,
    ts.waker_utid,
    ts.ts as block_ts,
    ts.dur as block_dur
  FROM thread_state ts
  JOIN process_threads pt ON ts.utid = pt.utid
  WHERE ts.state IN ('S', 'D')
    AND ts.waker_utid IS NOT NULL
    AND ts.ts >= ${start_ts} AND ts.ts < ${end_ts}
    AND ts.dur > ${min_block_ms|1} * 1000000
),
-- 关联唤醒者的线程信息和进程信息
with_waker_info AS (
  SELECT
    be.*,
    COALESCE(wt.name, 'unknown') as waker_thread,
    COALESCE(wp.name, 'unknown') as waker_process,
    wt.utid as waker_utid_resolved
  FROM blocking_events be
  LEFT JOIN thread wt ON be.waker_utid = wt.utid
  LEFT JOIN process wp ON wt.upid = wp.upid
),
-- 查找唤醒者在唤醒时刻正在执行的最内层 slice
with_waker_slice AS (
  SELECT
    wi.*,
    (SELECT s.name FROM slice s
     JOIN thread_track tt ON s.track_id = tt.id
     WHERE tt.utid = wi.waker_utid_resolved
       AND s.ts <= wi.block_ts + wi.block_dur
       AND s.ts + s.dur >= wi.block_ts + wi.block_dur
     ORDER BY s.dur ASC
     LIMIT 1) as waker_current_slice
  FROM with_waker_info wi
)
-- 聚合：按阻塞线程 × 唤醒者 × 阻塞函数分组
SELECT
  blocked_thread,
  blocked_role,
  blocked_state,
  COALESCE(blocked_function, '-') as blocked_function,
  waker_thread,
  waker_process,
  COALESCE(waker_current_slice, '-') as waker_current_slice,
  COUNT(*) as block_count,
  ROUND(SUM(block_dur) / 1e6, 2) as total_block_ms,
  ROUND(MAX(block_dur) / 1e6, 2) as max_block_ms,
  ROUND(AVG(block_dur) / 1e6, 2) as avg_block_ms
FROM with_waker_slice
GROUP BY blocked_thread, blocked_role, blocked_state, blocked_function,
         waker_thread, waker_process
ORDER BY
  CASE blocked_role WHEN 'main' THEN 0 WHEN 'render' THEN 1 ELSE 2 END,
  total_block_ms DESC
LIMIT ${top_k|20}
