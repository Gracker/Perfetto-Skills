-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/trace_state_track_summary.skill.yaml
-- Source SHA-256: 2cdb80f8ba21476ade7c51c601baad2f3af62cfa24ec319d2506c30c043c5699
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH input AS (
  SELECT MIN(MAX(COALESCE(${max_rows|80}, 80), 1), 500) AS max_rows
),
filtered AS (
  SELECT
    s.ts,
    s.dur,
    COALESCE(t.name, printf('track:%d', s.track_id)) AS track_name,
    COALESCE(s.category, '') AS category,
    COALESCE(s.value, '') AS state_value
  FROM state AS s
  LEFT JOIN track AS t
    ON t.id = s.track_id
  WHERE s.dur > 0
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
    AND ('${track_name|}' = '' OR LOWER(COALESCE(t.name, '')) GLOB '*' || LOWER('${track_name|}') || '*')
    AND ('${category|}' = '' OR LOWER(COALESCE(s.category, '')) GLOB '*' || LOWER('${category|}') || '*')
),
totals AS (
  SELECT SUM(dur) AS total_dur
  FROM filtered
),
grouped AS (
  SELECT
    track_name,
    category,
    state_value,
    COUNT(*) AS event_count,
    ROUND(SUM(dur) / 1e6, 2) AS total_dur_ms,
    ROUND(AVG(dur) / 1e6, 2) AS avg_dur_ms,
    ROUND(MAX(dur) / 1e6, 2) AS max_dur_ms,
    printf('%d', MIN(ts)) AS first_ts,
    printf('%d', MAX(ts)) AS last_ts,
    ROUND(100.0 * SUM(dur) / NULLIF((SELECT total_dur FROM totals), 0), 2) AS share_pct
  FROM filtered
  GROUP BY track_name, category, state_value
  ORDER BY SUM(dur) DESC
  LIMIT (SELECT max_rows FROM input)
)
SELECT *
FROM grouped
UNION ALL
SELECT
  'state' AS track_name,
  '' AS category,
  'no_state_rows' AS state_value,
  0 AS event_count,
  0 AS total_dur_ms,
  0 AS avg_dur_ms,
  0 AS max_dur_ms,
  '0' AS first_ts,
  '0' AS last_ts,
  0 AS share_pct
WHERE NOT EXISTS (SELECT 1 FROM filtered)
