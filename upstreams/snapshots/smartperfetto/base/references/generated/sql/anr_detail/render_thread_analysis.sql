-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: e48c73408b2775bed099612d32832cde9f70ca33cd1cc462e0275b1454588359
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH render_thread AS (
  SELECT t.utid, t.tid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (
      (${upid} > 0 AND p.upid = ${upid})
      OR (${upid} <= 0 AND ${pid} > 0 AND p.pid = ${pid}
          AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
      OR (${upid} <= 0 AND ${pid} <= 0
          AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
    )
    AND t.name = 'RenderThread'
  LIMIT 1
),
anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} as start_ts,
    ${anr_ts} as end_ts
),
rt_states AS (
  SELECT
    ts.state,
    ts.blocked_function,
    SUM(
      MIN(CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END, aw.end_ts)
        - MAX(ts.ts, aw.start_ts)
    ) as dur_ns
  FROM thread_state ts
  JOIN render_thread rt ON ts.utid = rt.utid
  CROSS JOIN anr_window aw
  WHERE ts.ts < aw.end_ts
    AND (CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END) > aw.start_ts
  GROUP BY ts.state, ts.blocked_function
),
rt_slices AS (
  SELECT
    s.name,
    SUM(
      MIN(CASE WHEN s.dur < 0 THEN aw.end_ts ELSE s.ts + s.dur END, aw.end_ts)
        - MAX(s.ts, aw.start_ts)
    ) as dur_ns,
    COUNT(*) as count
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN render_thread rt ON tt.utid = rt.utid
  CROSS JOIN anr_window aw
  WHERE s.ts < aw.end_ts
    AND (CASE WHEN s.dur < 0 THEN aw.end_ts ELSE s.ts + s.dur END) > aw.start_ts
    AND (s.name LIKE '%nSyncDraw%' OR s.name LIKE '%dequeueBuffer%'
         OR s.name LIKE '%DrawFrame%' OR s.name LIKE '%syncFrameState%')
  GROUP BY s.name
)
SELECT
  'state' as type,
  COALESCE(blocked_function, state) as name,
  ROUND(dur_ns / 1e6, 2) as dur_ms,
  ROUND(100.0 * dur_ns / ${timeout_ns}, 1) as pct
FROM rt_states
WHERE dur_ns > 1000000  -- > 1ms
UNION ALL
SELECT
  'slice' as type,
  name,
  ROUND(dur_ns / 1e6, 2) as dur_ms,
  ROUND(100.0 * dur_ns / ${timeout_ns}, 1) as pct
FROM rt_slices
WHERE dur_ns > 1000000
ORDER BY dur_ms DESC
LIMIT 10
