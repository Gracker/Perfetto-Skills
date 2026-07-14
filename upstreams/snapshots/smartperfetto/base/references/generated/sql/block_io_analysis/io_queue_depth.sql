-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/block_io_analysis.skill.yaml
-- Source SHA-256: 6694949cda0a83aa4448782fcdc7b6b7fb8c62134598018d5f702eb571a23985
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

SELECT
  dev,
  MAX(ops_in_queue_or_device) AS max_queue_depth,
  ROUND(AVG(ops_in_queue_or_device), 1) AS avg_queue_depth
FROM linux_active_block_io_operations_by_device
WHERE (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
  AND (CASE WHEN '${device}' != '' THEN dev GLOB '*${device}*' ELSE 1 END)
GROUP BY dev
ORDER BY max_queue_depth DESC
