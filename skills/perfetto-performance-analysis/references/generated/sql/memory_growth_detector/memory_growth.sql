-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/memory_growth_detector.skill.yaml
-- Source SHA-256: d088a4f84486f3486d78bca495692f08bcfb5082ca1116aa968809851ef1873d
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${growth_warning_mb}, 50) AS growth_warning_mb,
    COALESCE(${growth_pct_min_mb|5}, 5) AS growth_pct_min_mb,
    COALESCE(${growth_warning_pct|20}, 20) AS growth_warning_pct,
    COALESCE(${growth_critical_pct|50}, 50) AS growth_critical_pct,
    COALESCE(${jump_warning_mb|10}, 10) AS jump_warning_mb,
    COALESCE(${peak_avg_warning_ratio|2}, 2) AS peak_avg_warning_ratio,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (
      SELECT COALESCE(MAX(ts + CASE WHEN dur > 0 THEN dur ELSE 1 END), 0)
      FROM memory_rss_and_swap_per_process
    )) AS end_ts
),
samples AS (
  SELECT
    upid,
    pid,
    process_name,
    ts,
    dur,
    CASE WHEN dur > 0 THEN dur ELSE 0 END AS sample_dur,
    rss,
    COALESCE(swap, 0) AS swap,
    anon_rss_and_swap
  FROM memory_rss_and_swap_per_process, input
  WHERE (input.target_process = '' OR process_name GLOB input.target_process || '*')
    AND ts >= input.start_ts
    AND ts < input.end_ts
    AND rss IS NOT NULL
),
ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY upid ORDER BY ts ASC) AS rn_first,
    ROW_NUMBER() OVER (PARTITION BY upid ORDER BY ts DESC) AS rn_last,
    LAG(rss) OVER (PARTITION BY upid ORDER BY ts ASC) AS prev_rss
  FROM samples
),
aggregated AS (
  SELECT
    upid,
    pid,
    process_name,
    COUNT(*) AS samples,
    MAX(CASE WHEN rn_first = 1 THEN rss END) AS first_rss,
    MAX(CASE WHEN rn_last = 1 THEN rss END) AS last_rss,
    MIN(ts) AS first_ts,
    MAX(ts + sample_dur) AS last_ts,
    MAX(rss) AS max_rss,
    CASE
      WHEN SUM(sample_dur) > 0 THEN SUM(CAST(rss AS REAL) * sample_dur) / SUM(sample_dur)
      ELSE AVG(rss)
    END AS avg_rss,
    MAX(CASE WHEN prev_rss IS NOT NULL AND rss > prev_rss THEN rss - prev_rss ELSE 0 END) AS max_single_jump,
    MAX(100.0 * COALESCE(anon_rss_and_swap, 0) / NULLIF(rss, 0)) AS max_anon_ratio_pct,
    MAX(CASE WHEN rn_first = 1 THEN swap END) AS first_swap,
    MAX(CASE WHEN rn_last = 1 THEN swap END) AS last_swap
  FROM ranked
  GROUP BY upid, pid, process_name
)
SELECT
  process_name,
  upid,
  pid,
  samples,
  ROUND((last_ts - first_ts) / 1e9, 2) AS duration_s,
  ROUND(first_rss / 1024.0 / 1024.0, 2) AS first_rss_mb,
  ROUND(last_rss / 1024.0 / 1024.0, 2) AS last_rss_mb,
  ROUND((last_rss - first_rss) / 1024.0 / 1024.0, 2) AS rss_growth_mb,
  ROUND(100.0 * (last_rss - first_rss) / NULLIF(first_rss, 0), 2) AS rss_growth_pct,
  ROUND(((last_rss - first_rss) / 1024.0 / 1024.0) / NULLIF((last_ts - first_ts) / 1e9, 0), 4) AS rss_slope_mb_s,
  ROUND(max_single_jump / 1024.0 / 1024.0, 2) AS max_single_jump_mb,
  ROUND(max_rss / 1024.0 / 1024.0, 2) AS max_rss_mb,
  ROUND(avg_rss / 1024.0 / 1024.0, 2) AS avg_rss_mb,
  ROUND(max_rss / NULLIF(avg_rss, 0), 2) AS peak_avg_ratio,
  ROUND(max_anon_ratio_pct, 2) AS max_anon_ratio_pct,
  ROUND((last_swap - first_swap) / 1024.0 / 1024.0, 2) AS swap_growth_mb,
  CASE
    WHEN 100.0 * (last_rss - first_rss) / NULLIF(first_rss, 0) >= (SELECT growth_critical_pct FROM input)
      AND (last_rss - first_rss) / 1024.0 / 1024.0 >= (SELECT growth_pct_min_mb FROM input) THEN 'critical'
    WHEN (last_rss - first_rss) / 1024.0 / 1024.0 > (SELECT growth_warning_mb * 2 FROM input) THEN 'critical'
    WHEN 100.0 * (last_rss - first_rss) / NULLIF(first_rss, 0) >= (SELECT growth_warning_pct FROM input)
      AND (last_rss - first_rss) / 1024.0 / 1024.0 >= (SELECT growth_pct_min_mb FROM input) THEN 'warning'
    WHEN (last_rss - first_rss) / 1024.0 / 1024.0 > (SELECT growth_warning_mb FROM input) THEN 'warning'
    WHEN max_single_jump / 1024.0 / 1024.0 >= (SELECT jump_warning_mb FROM input) THEN 'warning'
    WHEN max_rss / NULLIF(avg_rss, 0) >= (SELECT peak_avg_warning_ratio FROM input) THEN 'warning'
    WHEN max_anon_ratio_pct >= 70
      AND (last_rss - first_rss) / 1024.0 / 1024.0 >= (SELECT growth_pct_min_mb FROM input) THEN 'notice'
    WHEN (last_swap - first_swap) > 0 THEN 'notice'
    ELSE 'normal'
  END AS rating
FROM aggregated
WHERE samples >= 2
ORDER BY rss_growth_mb DESC
LIMIT 100
