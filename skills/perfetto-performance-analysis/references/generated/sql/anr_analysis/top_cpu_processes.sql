-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: b4477788d50246d11d2483cd0837b27f8088afd90565197ab4f32613a52e680d
-- Source commit: 00559cb4068232b511e24c614eadcad0b122bdc5

WITH anr_window AS (
  SELECT
    ${anr_ctx.data[0].anr_ts} - ${anr_ctx.data[0].timeout_ns} AS start_ts,
    ${anr_ctx.data[0].anr_ts} AS end_ts,
    ${anr_ctx.data[0].timeout_ns} AS window_ns
),
clipped AS (
  SELECT
    p.name AS process_name,
    MIN(CASE WHEN ss.dur < 0 THEN aw.end_ts ELSE ss.ts + ss.dur END, aw.end_ts)
      - MAX(ss.ts, aw.start_ts) AS clipped_ns
  FROM sched_slice ss
  JOIN thread t ON ss.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN anr_window aw
  WHERE ss.ts < aw.end_ts
    AND (CASE WHEN ss.dur < 0 THEN aw.end_ts ELSE ss.ts + ss.dur END) > aw.start_ts
)
SELECT
  process_name,
  ROUND(SUM(clipped_ns) / 1e6, 2) AS cpu_ms,
  ROUND(100.0 * SUM(clipped_ns) / NULLIF((SELECT window_ns FROM anr_window), 0), 1) AS cpu_pct
FROM clipped
GROUP BY process_name
ORDER BY cpu_ms DESC
LIMIT 15
