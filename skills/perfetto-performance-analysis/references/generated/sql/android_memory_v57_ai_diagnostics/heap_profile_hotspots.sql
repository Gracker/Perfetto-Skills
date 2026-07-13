-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: 7dc0d526cc82e5a6cdcf44d923ed6b520120af61b4527abee948ab91566875da
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

WITH input AS (
  SELECT
    COALESCE(${min_size_mb|1}, 1) AS min_size_mb,
    MIN(MAX(COALESCE(${max_rows|40}, 40), 1), 500) AS max_rows
)
SELECT
  'all_profiled_processes' AS scope,
  COALESCE(name, '[unknown]') AS name,
  COALESCE(mapping_name, '') AS mapping_name,
  ROUND(self_size / 1048576.0, 2) AS self_size_mb,
  ROUND(cumulative_size / 1048576.0, 2) AS cumulative_size_mb,
  ROUND(self_alloc_size / 1048576.0, 2) AS self_alloc_mb,
  ROUND(cumulative_alloc_size / 1048576.0, 2) AS cumulative_alloc_mb,
  CASE
    WHEN self_size >= input.min_size_mb * 1048576.0 THEN 'unreleased_leaf_retention'
    WHEN cumulative_size >= input.min_size_mb * 1048576.0 THEN 'unreleased_cumulative_retention'
    WHEN cumulative_alloc_size >= input.min_size_mb * 1048576.0 * 5 THEN 'allocation_churn'
    ELSE 'inspect_if_relevant'
  END AS allocation_signal,
  COALESCE(source_file, '') AS source_file
FROM android_heap_profile_summary_tree, input
WHERE self_size >= input.min_size_mb * 1048576.0
  OR cumulative_size >= input.min_size_mb * 1048576.0
  OR cumulative_alloc_size >= input.min_size_mb * 1048576.0 * 5
ORDER BY self_size DESC, cumulative_size DESC, cumulative_alloc_size DESC
LIMIT (SELECT max_rows FROM input)
