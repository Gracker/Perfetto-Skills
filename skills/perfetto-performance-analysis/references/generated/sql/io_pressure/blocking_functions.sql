-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/io_pressure.skill.yaml
-- Source SHA-256: 0a450c93ae1f945c82729a14f132f2006df7bf395e1ffa1fd86ae69180fa5a23
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  COALESCE(blocked_function, 'unknown') as blocked_function,
  COUNT(*) as block_count,
  ROUND(SUM(dur) / 1e6, 2) as total_block_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_block_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_block_ms,
  CASE
    WHEN blocked_function LIKE '%f2fs%' OR blocked_function LIKE '%ext4%' THEN 'filesystem'
    WHEN blocked_function LIKE '%read%' OR blocked_function LIKE '%write%' THEN 'read_write'
    WHEN blocked_function LIKE '%sync%' OR blocked_function LIKE '%fsync%' THEN 'sync'
    WHEN blocked_function LIKE '%io%' OR blocked_function LIKE '%blk%' THEN 'block_io'
    ELSE 'other'
  END as category
FROM thread_state
WHERE state IN ('D', 'DK')
  AND (
    COALESCE(io_wait, 0) = 1
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%filemap%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%page_fault%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%wait_on_page%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%folio_wait%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%io_schedule%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%submit_bio%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%blk_%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%ext4%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%f2fs%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%erofs%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%ufshcd%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%mmc_%'
    OR LOWER(COALESCE(blocked_function, '')) LIKE '%dm_%'
  )
  AND dur > ${min_duration_ms|1} * 1e6
  AND blocked_function IS NOT NULL
  AND blocked_function != ''
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY blocked_function
ORDER BY total_block_ms DESC
LIMIT ${max_items|20}
