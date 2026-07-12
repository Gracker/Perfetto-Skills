-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 9a20a24042252892aabc8ff420a5f4777953bd6c041b00285dc3402f3cf6182e
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH anr_window AS (
  SELECT
    ${anr_ctx.data[0].anr_ts} - ${anr_ctx.data[0].timeout_ns} AS start_ts,
    ${anr_ctx.data[0].anr_ts} AS end_ts
),
app_activity AS (
  SELECT
    p.name as process_name,
    SUM(CASE WHEN ts.state = 'Running' THEN
      MIN(CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END, aw.end_ts)
        - MAX(ts.ts, aw.start_ts)
    ELSE 0 END) as running_ns,
    SUM(
      MIN(CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END, aw.end_ts)
        - MAX(ts.ts, aw.start_ts)
    ) as total_ns
  FROM thread_state ts
  CROSS JOIN anr_window aw
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE ts.ts < aw.end_ts
    AND (CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END) > aw.start_ts
    AND t.tid = p.pid  -- 主线程
    AND (
      COALESCE(p.uid, 0) >= 10000
      OR p.name = 'system_server'
      OR p.name = 'com.android.systemui'
    )
  GROUP BY p.name
),
freeze_eval AS (
  SELECT
    process_name,
    100.0 * running_ns / NULLIF(total_ns, 0) as running_pct
  FROM app_activity
)
SELECT
  COUNT(*) as total_apps,
  SUM(CASE WHEN running_pct < 5 THEN 1 ELSE 0 END) as frozen_apps,
  ROUND(100.0 * SUM(CASE WHEN running_pct < 5 THEN 1 ELSE 0 END) /
        NULLIF(COUNT(*), 0), 1) as frozen_pct,
  MAX(CASE WHEN process_name = 'system_server' THEN ROUND(running_pct, 1) END) as system_server_running_pct,
  MAX(CASE WHEN process_name = 'system_server' AND running_pct < 5 THEN 1 ELSE 0 END) as system_server_frozen,
  CASE
    WHEN MAX(CASE WHEN process_name = 'system_server' AND running_pct < 5 THEN 1 ELSE 0 END) = 1
      THEN 'system_server_freeze'
    WHEN 100.0 * SUM(CASE WHEN running_pct < 5 THEN 1 ELSE 0 END) /
         NULLIF(COUNT(*), 0) > 50 THEN 'system_freeze'
    ELSE 'app_specific'
  END as freeze_verdict
FROM freeze_eval
