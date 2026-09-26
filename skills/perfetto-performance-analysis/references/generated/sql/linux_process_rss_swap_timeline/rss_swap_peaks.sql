-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/linux_process_rss_swap_timeline.skill.yaml
-- Source SHA-256: fa2db2d7e72b53fb5ad2fd529a8be2e71817754cc77655a857181afb81023a04
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (
      SELECT COALESCE(MAX(ts + CASE WHEN dur > 0 THEN dur ELSE 1 END), 0)
      FROM memory_rss_and_swap_per_process
    )) AS end_ts
)
SELECT
  process_name,
  COUNT(*) AS samples,
  ROUND(MAX(rss) / 1024.0 / 1024.0, 2) AS max_rss_mb,
  ROUND(MAX(anon_rss_and_swap) / 1024.0 / 1024.0, 2) AS max_anon_swap_mb,
  ROUND(MAX(COALESCE(swap, 0)) / 1024.0 / 1024.0, 2) AS max_swap_mb
FROM memory_rss_and_swap_per_process, input
WHERE (input.target_process = '' OR process_name = input.target_process OR process_name GLOB input.target_process || ':*')
  AND ts >= input.start_ts
  AND ts < input.end_ts
GROUP BY process_name
ORDER BY max_anon_swap_mb DESC
LIMIT 100
