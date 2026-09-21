-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/blocking_chain_analysis.skill.yaml
-- Source SHA-256: 68f73be9504b37b7a6d8966693adf2fe179f9183db279f10d9fe883226dfa5c9
-- Source commit: bc007586871a720aed82537913617c64fb95a459

-- Perfetto 只把 waker_utid 记录在唤醒后的第一个 R/R+ 行上；S/D 等待行自身的
-- waker_utid 为 NULL。因此把每个等待行回连到其结束时刻的后继行解析唤醒者；
-- 同一结束时刻被拆成多行（R → R+）时用 MAX 收敛为一段等待一行。
WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = '${process_name}' OR p.name GLOB '${process_name}*')
    AND (t.is_main_thread = 1 OR t.tid = p.pid)
  ORDER BY
    (p.name = '${process_name}') DESC,
    EXISTS(SELECT 1 FROM thread_state ts WHERE ts.utid = t.utid) DESC,
    t.utid
  LIMIT 1
),
waits AS (
  SELECT
    t.id AS state_id,
    t.ts + t.dur AS wakeup_ts,
    t.dur AS sleep_dur,
    t.blocked_function,
    MAX(w.waker_utid) AS waker_utid
  FROM thread_state t
  CROSS JOIN main_thread mt
  LEFT JOIN thread_state w
    ON w.utid = t.utid
    AND w.ts = t.ts + t.dur
    AND w.state IN ('R', 'R+')
    AND w.waker_utid IS NOT NULL
  WHERE t.utid = mt.utid
    AND t.state IN ('S', 'D')
    AND t.dur > 0
    AND t.ts + t.dur > ${start_ts}
    AND t.ts < ${end_ts}
  GROUP BY t.id
)
SELECT
  printf('%d', MIN(wakeup_ts)) as ts,
  wt.name as waker_thread_name,
  wp.name as waker_process_name,
  blocked_function,
  ROUND(SUM(sleep_dur) / 1e6, 2) as total_sleep_dur_ms,
  ROUND(MAX(sleep_dur) / 1e6, 2) as max_sleep_dur_ms,
  COUNT(*) as wakeup_count
FROM waits
JOIN thread wt ON wt.utid = waits.waker_utid
LEFT JOIN process wp ON wt.upid = wp.upid
GROUP BY wt.name, wp.name, blocked_function
ORDER BY SUM(sleep_dur) DESC
LIMIT 15
