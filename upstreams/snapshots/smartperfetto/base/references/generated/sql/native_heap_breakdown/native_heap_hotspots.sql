-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/native_heap_breakdown.skill.yaml
-- Source SHA-256: 9de17b88dbea86451c2107ac4494967a6a6bb290b473eefe52f7650cc9e00550
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH input AS (
  SELECT
    COALESCE(${min_size_mb|1}, 1) AS min_size_mb,
    COALESCE(${min_alloc_mb|0}, 0) AS min_alloc_mb,
    MIN(MAX(COALESCE(${max_rows|100}, 100), 1), 500) AS max_rows
)
SELECT
  name,
  mapping_name,
  ROUND(cumulative_size / 1024.0 / 1024.0, 2) AS cumulative_size_mb,
  ROUND(self_size / 1024.0 / 1024.0, 2) AS self_size_mb,
  ROUND(cumulative_alloc_size / 1024.0 / 1024.0, 2) AS cumulative_alloc_mb,
  ROUND(100.0 * cumulative_size / NULLIF(cumulative_alloc_size, 0), 2) AS unreleased_to_alloc_pct,
  ROUND(1.0 * cumulative_alloc_size / NULLIF(cumulative_size, 0), 2) AS churn_ratio,
  CASE
    WHEN cumulative_size >= input.min_size_mb * 1024.0 * 1024.0
      AND cumulative_alloc_size >= cumulative_size * 5
      THEN 'retention_with_churn'
    WHEN cumulative_size >= input.min_size_mb * 1024.0 * 1024.0
      THEN 'unreleased_native_retention'
    WHEN input.min_alloc_mb > 0
      AND cumulative_alloc_size >= input.min_alloc_mb * 1024.0 * 1024.0
      THEN 'allocation_churn'
    ELSE 'inspect_if_relevant'
  END AS native_signal,
  source_file
FROM android_heap_profile_summary_tree, input
WHERE cumulative_size >= input.min_size_mb * 1024.0 * 1024.0
  OR (
    input.min_alloc_mb > 0
    AND cumulative_alloc_size >= input.min_alloc_mb * 1024.0 * 1024.0
  )
ORDER BY cumulative_size DESC, cumulative_alloc_size DESC
LIMIT (SELECT max_rows FROM input)
