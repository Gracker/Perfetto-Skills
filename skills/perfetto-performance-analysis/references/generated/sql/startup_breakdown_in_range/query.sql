-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_breakdown_in_range.skill.yaml
-- Source SHA-256: acdca121c21c877922518048f6698fead940d1d8dadf91209910bbcd4be3810b
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  b.reason,
  COUNT(*) as count,
  SUM(b.dur) / 1e6 as total_dur_ms,
  ROUND(AVG(b.dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(b.dur) / 1e6, 2) as max_dur_ms,
  ROUND(100.0 * SUM(b.dur) / (
    SELECT SUM(dur) FROM android_startup_opinionated_breakdown
    WHERE startup_id IN (
      SELECT startup_id FROM android_startups
      WHERE (package GLOB '${package}*' OR '${package}' = '')
        AND (${startup_id} IS NULL OR startup_id = ${startup_id})
        AND (${start_ts} IS NULL OR ts >= ${start_ts})
        AND (${end_ts} IS NULL OR ts + dur <= ${end_ts})
    )
  ), 1) as percent,
  CASE
    WHEN b.reason GLOB '*binder*' THEN 'IPC'
    WHEN b.reason GLOB '*io*' OR b.reason GLOB '*dlopen*' THEN 'IO'
    WHEN b.reason GLOB '*gc*' OR b.reason GLOB '*memory*' THEN 'Memory'
    WHEN b.reason GLOB '*lock*' OR b.reason GLOB '*contention*' THEN 'Lock'
    WHEN b.reason GLOB '*inflate*' THEN 'Layout'
    WHEN b.reason GLOB '*verify*' OR b.reason GLOB '*dex*' THEN 'ClassLoading'
    ELSE 'Other'
  END as category
FROM android_startup_opinionated_breakdown b
JOIN android_startups s ON b.startup_id = s.startup_id
WHERE (s.package GLOB '${package}*' OR '${package}' = '')
  AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
GROUP BY b.reason
ORDER BY total_dur_ms DESC
LIMIT ${top_k|15}
