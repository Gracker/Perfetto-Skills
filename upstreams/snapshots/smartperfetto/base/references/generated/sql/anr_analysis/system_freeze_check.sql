-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 886c11c88b8de59f7a759bb5510cc207277be4fee7d37149ed00f9c1c29c96f9

WITH anr_window AS (
  SELECT
    ${anr_ctx.data[0].anr_ts} - ${anr_ctx.data[0].timeout_ns} AS start_ts,
    ${anr_ctx.data[0].anr_ts} AS end_ts,
    ${anr_ctx.data[0].timeout_ns} AS window_ns,
    ${anr_ctx.data[0].upid|NULL} AS anr_upid
),
main_thread_states AS (
  SELECT
    p.upid,
    p.name AS process_name,
    ts.state,
    MIN(CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END, aw.end_ts)
      - MAX(ts.ts, aw.start_ts) AS clipped_ns
  FROM thread_state ts
  CROSS JOIN anr_window aw
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE ts.ts < aw.end_ts
    AND (CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END) > aw.start_ts
    AND t.tid = p.pid  -- 主线程
    -- Regular app uids (isolated and app-zygote ranges excluded), plus
    -- system_server; a process without a uid is not sampled.
    AND (
      COALESCE(p.uid, 0) % 100000 BETWEEN 10000 AND 89999
      OR p.name = 'system_server'
    )
),
-- One row per process (a name can belong to several), over its alive
-- time: a dead (Z, X, x) main thread is not frozen.
main_threads AS (
  SELECT
    upid,
    process_name,
    SUM(CASE WHEN upper(state) NOT IN ('Z', 'X') THEN clipped_ns ELSE 0 END) AS alive_ns,
    SUM(CASE WHEN state = 'Running' THEN clipped_ns ELSE 0 END) AS running_ns,
    SUM(CASE WHEN state IN ('R', 'R+', 'D', 'DK') THEN clipped_ns ELSE 0 END) AS stalled_ns
  FROM main_thread_states
  GROUP BY upid, process_name
),
-- Evaluable: alive for at least 90% of the window. Stalled: runnable or
-- uninterruptible for at least half of that alive time.
evaluated AS (
  SELECT
    process_name,
    upid IS NOT anr_upid AS sampled,
    100.0 * running_ns / alive_ns AS running_pct,
    100.0 * stalled_ns / alive_ns AS stalled_time_pct,
    CASE WHEN running_ns + stalled_ns >= 0.1 * alive_ns THEN 1 ELSE 0 END AS demanding,
    CASE WHEN stalled_ns >= 0.5 * alive_ns THEN 1 ELSE 0 END AS stalled
  FROM main_threads, anr_window
  WHERE alive_ns >= 0.9 * window_ns
),
verdict_input AS (
  SELECT
    COUNT(*) AS total_apps,
    SUM(CASE WHEN sampled AND process_name IS NOT 'system_server' THEN demanding ELSE 0 END) AS demanding_apps,
    SUM(CASE WHEN sampled AND process_name IS NOT 'system_server' THEN stalled ELSE 0 END) AS stalled_apps,
    COALESCE(MAX(CASE WHEN process_name = 'system_server' THEN 1 ELSE 0 END), 0) AS system_server_evaluated,
    MAX(CASE WHEN process_name = 'system_server' THEN stalled END) AS system_server_stalled,
    MAX(CASE WHEN process_name = 'system_server' THEN ROUND(stalled_time_pct, 1) END) AS system_server_stalled_pct,
    MAX(CASE WHEN process_name = 'system_server' THEN ROUND(running_pct, 1) END) AS system_server_running_pct
  FROM evaluated
)
SELECT
  total_apps,
  COALESCE(demanding_apps, 0) AS demanding_apps,
  COALESCE(stalled_apps, 0) AS stalled_apps,
  ROUND(100.0 * stalled_apps / NULLIF(demanding_apps, 0), 1) AS stalled_pct,
  system_server_evaluated,
  system_server_stalled_pct,
  system_server_running_pct,
  CASE
    WHEN system_server_stalled = 1 THEN 'system_server_freeze'
    WHEN demanding_apps >= 3 AND 2 * stalled_apps > demanding_apps THEN 'system_freeze'
    WHEN system_server_evaluated = 0 THEN 'undetermined'
    ELSE 'app_specific'
  END AS freeze_verdict
FROM verdict_input
