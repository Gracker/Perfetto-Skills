-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/io_pressure.skill.yaml
-- Source SHA-256: 4799f46bab6741b4894853f4a43ace14682cc8fff4ebdcb8cfc01e9c3606f571
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM thread_state ts
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
    LIMIT 1
  ) THEN 1 ELSE 0 END as has_data,
  CASE WHEN EXISTS (
    SELECT 1 FROM thread_state ts
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
      AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
      AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
    LIMIT 1
  ) THEN 1 ELSE 0 END as has_long_io,
  CASE WHEN EXISTS (
    SELECT 1 FROM thread_state ts
    WHERE ts.blocked_function IS NOT NULL
      AND ts.blocked_function != ''
      AND ts.state IN ('D', 'DK')
      AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
      AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
    LIMIT 1
  ) THEN 1 ELSE 0 END as has_blocked_functions
