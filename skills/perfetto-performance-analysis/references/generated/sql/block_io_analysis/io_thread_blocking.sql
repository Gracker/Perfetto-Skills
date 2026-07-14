-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/block_io_analysis.skill.yaml
-- Source SHA-256: 6694949cda0a83aa4448782fcdc7b6b7fb8c62134598018d5f702eb571a23985
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  t.name AS thread_name,
  p.name AS process_name,
  ts.blocked_function,
  ts.io_wait,
  CASE
    WHEN COALESCE(ts.io_wait, 0) = 1 THEN 'direct_io_wait'
    ELSE 'inferred_io_or_page_cache'
  END AS evidence_strength,
  COUNT(*) AS block_count,
  ROUND(SUM(ts.dur) / 1e6, 2) AS total_blocked_ms,
  ROUND(AVG(ts.dur) / 1e6, 2) AS avg_blocked_ms
FROM thread_state ts
JOIN thread t ON ts.utid = t.utid
LEFT JOIN process p ON t.upid = p.upid
WHERE ts.state IN ('D', 'DK')
  AND (
    COALESCE(ts.io_wait, 0) = 1
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%filemap%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%page_fault%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%wait_on_page%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%folio_wait%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%io_schedule%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%submit_bio%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%sync%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%blk_%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%ext4%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%f2fs%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%erofs%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%ufshcd%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%mmc_%'
    OR LOWER(COALESCE(ts.blocked_function, '')) LIKE '%dm_%'
  )
  AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
GROUP BY t.name, p.name, ts.blocked_function, ts.io_wait
HAVING total_blocked_ms > 10
ORDER BY total_blocked_ms DESC
LIMIT 30
