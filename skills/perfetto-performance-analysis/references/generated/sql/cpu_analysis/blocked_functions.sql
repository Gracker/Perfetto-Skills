-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: b3ab914b724ad69264ba04c73c6cb054a3567de1ffde3e53768eb349ac5d3afe
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.upid = ${target_process.data[0].upid} AND t.tid = p.pid
  LIMIT 1
)
SELECT
  ts.blocked_function,
  ts.state,
  COALESCE(ts.io_wait, 0) as io_wait,
  CASE
    WHEN ts.state IN ('D', 'DK') AND COALESCE(ts.io_wait, 0) = 1 THEN 'direct_io_wait'
    WHEN ts.state IN ('D', 'DK') AND (
      LOWER(COALESCE(ts.blocked_function, '')) LIKE '%filemap%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%page_fault%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%wait_on_page%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%io_schedule%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%submit_bio%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%blk_%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%ext4%'
      OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%f2fs%'
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
  COUNT(*) as count,
  SUM(ts.dur) / 1e6 as total_dur_ms,
  ROUND(AVG(ts.dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(ts.dur) / 1e6, 2) as max_dur_ms
FROM thread_state ts
WHERE ts.utid = (SELECT utid FROM main_thread)
  AND ts.blocked_function IS NOT NULL
  AND ts.dur > 1000000  -- > 1ms
  AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
GROUP BY ts.blocked_function, ts.state, COALESCE(ts.io_wait, 0)
ORDER BY total_dur_ms DESC
LIMIT 15
