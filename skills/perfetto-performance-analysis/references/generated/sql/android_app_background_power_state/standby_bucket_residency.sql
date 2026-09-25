-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_app_background_power_state.skill.yaml
-- Source SHA-256: 4ce3166f6ef8db3eca68f7a14cb6d6164abb3f15de2db690e545acc15ef4ff86
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH bounds AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS window_start,
    COALESCE(${end_ts}, trace_end()) AS window_end
),
clipped AS (
  SELECT
    s.*,
    MIN(s.ts + s.dur, b.window_end) - MAX(s.ts, b.window_start) AS clipped_dur,
    ROW_NUMBER() OVER (
      PARTITION BY s.package_name, s.user_id, s.bucket ORDER BY s.ts DESC
    ) AS recency
  FROM android_standby_bucket AS s
  CROSS JOIN bounds AS b
  WHERE s.ts < b.window_end AND s.ts + s.dur > b.window_start
    -- Buckets belong to packages: `pkg:subprocess` matches `pkg`.
    AND (
      '${package}' = ''
      OR s.package_name = IIF(instr('${package}', ':') > 0,
        substr('${package}', 1, instr('${package}', ':') - 1), '${package}')
    )
)
SELECT
  package_name,
  user_id,
  bucket,
  ROUND(SUM(clipped_dur) / 1e6, 2) AS residency_ms,
  COUNT(*) AS entry_count,
  MAX(IIF(recency = 1, main_reason, NULL)) AS last_main_reason,
  printf('%d', MIN(ts)) AS first_entered_ts
FROM clipped
GROUP BY package_name, user_id, bucket
ORDER BY package_name, user_id, SUM(clipped_dur) DESC
