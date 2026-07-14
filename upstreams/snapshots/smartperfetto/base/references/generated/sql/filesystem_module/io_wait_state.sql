-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/filesystem_module.skill.yaml
-- Source SHA-256: f09b8fa67e639a8b6825f4e99517b4cf82b8fae75c585d2c96f928f28e3c7f24
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  t.name AS thread_name,
  CAST(SUM(ts.dur) / 1e6 AS INTEGER) AS io_wait_ms,
  COUNT(*) AS io_wait_count,
  CAST(AVG(ts.dur) / 1e6 AS REAL) AS avg_wait_ms
FROM thread_state ts
JOIN thread t USING (utid)
JOIN process p USING (upid)
WHERE p.name LIKE '%${package}%'
  AND ts.state IN ('D', 'DK')  -- Uninterruptible sleep; io_wait/function pattern required for IO attribution
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
  AND ts.dur > 1000000
GROUP BY t.utid
HAVING io_wait_ms > 5
ORDER BY io_wait_ms DESC
LIMIT 15
