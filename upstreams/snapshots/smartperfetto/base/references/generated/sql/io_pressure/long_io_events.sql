-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/io_pressure.skill.yaml
-- Source SHA-256: 4799f46bab6741b4894853f4a43ace14682cc8fff4ebdcb8cfc01e9c3606f571
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  printf('%d', ts.ts) as ts,
  ROUND(ts.dur / 1e6, 2) as duration_ms,
  t.name as thread_name,
  p.name as process_name,
  ts.state,
  COALESCE(ts.blocked_function, 'unknown') as blocked_function
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
  AND ts.dur > ${long_io_threshold_ms|10} * 1e6
  AND ('${package}' = '' OR p.name GLOB '${package}*')
  AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
ORDER BY ts.dur DESC
LIMIT ${max_items|20}
