-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/io_pressure.skill.yaml
-- Source SHA-256: 0a450c93ae1f945c82729a14f132f2006df7bf395e1ffa1fd86ae69180fa5a23
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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
