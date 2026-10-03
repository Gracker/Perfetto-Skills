-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 7ff32bd00930745e7472e3fd492581136074cf0cf6843caf8fecf18d85f1a757

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
