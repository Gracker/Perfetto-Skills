-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/block_io_analysis.skill.yaml
-- Source SHA-256: 6694949cda0a83aa4448782fcdc7b6b7fb8c62134598018d5f702eb571a23985
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  printf('%d', ts) AS ts,
  dev,
  ops_in_queue_or_device AS queue_depth
FROM linux_active_block_io_operations_by_device
WHERE ops_in_queue_or_device >= COALESCE(${min_queue_depth|5}, 5)
  AND (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
  AND (CASE WHEN '${device}' != '' THEN dev GLOB '*${device}*' ELSE 1 END)
ORDER BY ops_in_queue_or_device DESC
LIMIT 100
