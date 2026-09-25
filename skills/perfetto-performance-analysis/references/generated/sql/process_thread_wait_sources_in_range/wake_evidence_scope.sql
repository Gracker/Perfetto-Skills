-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/process_thread_wait_sources_in_range.skill.yaml
-- Source SHA-256: a63b33f91c961cf74a88510339a24499fc5a04d98ba04563ebe10ddd9bfc76e1
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

-- Perfetto 把 waker_utid 记录在睡眠之后的第一个 R/R+ 行上，所以"有没有唤醒证据"
-- 要数 R 行而不是 S 行。没有这些行时，S 态等待在内核侧完全不可归因。
WITH target_utids AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON p.upid = t.upid
  WHERE (${__process_scope.upid} IS NULL OR p.upid = ${__process_scope.upid})
    AND (
      ${__process_scope.upid} IS NOT NULL
      OR '${package}' = ''
      OR p.name = '${package}'
      OR p.name GLOB '${package}:*'
    )
    AND (${upid} IS NULL OR p.upid = ${upid})
    AND (${pid} IS NULL OR p.pid = ${pid})
)
SELECT
  CASE WHEN (
    SELECT COUNT(*) FROM thread_state s JOIN target_utids u ON u.utid = s.utid
    WHERE s.state IN ('R', 'R+') AND s.waker_utid IS NOT NULL
      AND s.ts < ${end_ts} AND s.ts + MAX(s.dur, 0) > ${start_ts}
  ) > 0 THEN 'available' ELSE 'unavailable' END AS status,
  'trace_direct:sched_waking' AS evidence_class,
  (SELECT COUNT(*) FROM thread_state s JOIN target_utids u ON u.utid = s.utid
    WHERE s.state IN ('R', 'R+') AND s.waker_utid IS NOT NULL
      AND s.ts < ${end_ts} AND s.ts + MAX(s.dur, 0) > ${start_ts}) AS waker_rows,
  (SELECT COUNT(*) FROM thread_state s JOIN target_utids u ON u.utid = s.utid
    WHERE s.state IN ('R', 'R+') AND s.irq_context = 1
      AND s.ts < ${end_ts} AND s.ts + MAX(s.dur, 0) > ${start_ts}) AS irq_wake_rows,
  (SELECT COUNT(*) FROM thread_state s JOIN target_utids u ON u.utid = s.utid
    WHERE s.state IN ('S', 'I') AND s.dur > 0
      AND s.ts < ${end_ts} AND s.ts + s.dur > ${start_ts}) AS sleep_rows,
  '唤醒者线程/进程、irq 上下文、同进程交接、binder 回复、系统服务唤醒' AS supported_claims,
  'S 态没有 blocked_function；irq 唤醒不等于网络收包；请求级 DNS/TCP/TLS/TTFB 与服务端耗时均不可证' AS unsupported_claims
