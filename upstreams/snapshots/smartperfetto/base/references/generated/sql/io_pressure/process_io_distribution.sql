-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/io_pressure.skill.yaml
-- Source SHA-256: 4799f46bab6741b4894853f4a43ace14682cc8fff4ebdcb8cfc01e9c3606f571
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH io_by_process AS (
  SELECT
    p.name as process_name, p.pid,
    SUM(ts.dur) / 1e6 as io_wait_ms,
    COUNT(*) as io_events,
    AVG(ts.dur) / 1e6 as avg_wait_ms
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
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
    AND ('${package}' = '' OR p.name GLOB '${package}*')
    AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
  GROUP BY p.upid
),
totals AS (
  SELECT SUM(io_wait_ms) as total_io_wait_ms FROM io_by_process
)
SELECT
  process_name, pid,
  ROUND(io_wait_ms, 2) as io_wait_ms,
  io_events,
  ROUND(avg_wait_ms, 2) as avg_wait_ms,
  ROUND(io_wait_ms * 100.0 / NULLIF((SELECT total_io_wait_ms FROM totals), 0), 1) as pct_of_total
FROM io_by_process
ORDER BY io_wait_ms DESC
LIMIT ${max_items|20}
