-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/io_pressure.skill.yaml
-- Source SHA-256: 0a450c93ae1f945c82729a14f132f2006df7bf395e1ffa1fd86ae69180fa5a23
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH io_wait_states AS (
  SELECT
    ts.utid, ts.ts, ts.dur, ts.state, ts.blocked_function, ts.io_wait
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
)
SELECT
  COUNT(*) as io_wait_events,
  ROUND(SUM(dur) / 1e6, 2) as total_io_wait_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_io_wait_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_io_wait_ms,
  COUNT(DISTINCT utid) as affected_threads,
  CASE
    WHEN SUM(dur) / 1e6 > ${critical_io_wait_ms|5000} THEN 'critical'
    WHEN SUM(dur) / 1e6 > ${warning_io_wait_ms|1000} THEN 'warning'
    WHEN SUM(dur) / 1e6 > 100 THEN 'info'
    ELSE 'normal'
  END as severity
FROM io_wait_states
