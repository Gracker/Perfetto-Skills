-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/futex_wait_distribution.skill.yaml
-- Source SHA-256: b4995afc55c08909120af15f468a3cfe33d21ec3543ae7509296c2f7dec683fd
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH bounds AS (
  SELECT
    COALESCE(${start_ts}, (SELECT COALESCE(MIN(ts), 0) FROM slice)) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(CASE WHEN dur < 0 THEN ts ELSE ts + dur END), 0) FROM slice)) AS end_ts
),
waits AS (
  SELECT
    CASE
      WHEN LOWER(s.name) LIKE '%futex%' THEN 'futex'
      WHEN LOWER(s.name) LIKE '%mutex%' THEN 'mutex'
      WHEN LOWER(s.name) LIKE '%rwlock%' OR LOWER(s.name) LIKE '%spinlock%' THEN 'lock'
      ELSE 'other'
    END as wait_type,
    (
      MIN(CASE WHEN s.dur < 0 THEN b.end_ts ELSE s.ts + s.dur END, b.end_ts)
        - MAX(s.ts, b.start_ts)
    ) / 1e6 as wait_ms
  FROM slice s
  CROSS JOIN bounds b
  LEFT JOIN thread_track tt ON s.track_id = tt.id
  LEFT JOIN thread t ON tt.utid = t.utid
  LEFT JOIN process p ON t.upid = p.upid
  WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND s.ts < b.end_ts
    AND (CASE WHEN s.dur < 0 THEN b.end_ts ELSE s.ts + s.dur END) > b.start_ts
    AND (
      LOWER(s.name) LIKE '%futex%'
      OR LOWER(s.name) LIKE '%mutex%'
      OR LOWER(s.name) LIKE '%rwlock%'
      OR LOWER(s.name) LIKE '%spinlock%'
    )
),
ranked AS (
  SELECT
    wait_type,
    wait_ms,
    PERCENT_RANK() OVER (PARTITION BY wait_type ORDER BY wait_ms) as pct
  FROM waits
)
SELECT
  wait_type,
  COUNT(*) as events,
  ROUND(AVG(wait_ms), 2) as avg_wait_ms,
  ROUND(MAX(CASE WHEN pct >= 0.95 THEN wait_ms END), 2) as p95_wait_ms,
  ROUND(MAX(wait_ms), 2) as max_wait_ms
FROM ranked
GROUP BY wait_type
ORDER BY avg_wait_ms DESC
