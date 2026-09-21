-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/blocking_chain_analysis.skill.yaml
-- Source SHA-256: 68f73be9504b37b7a6d8966693adf2fe179f9183db279f10d9fe883226dfa5c9
-- Source commit: bc007586871a720aed82537913617c64fb95a459

WITH RECURSIVE main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = '${process_name}' OR p.name GLOB '${process_name}*')
    AND (t.is_main_thread = 1 OR t.tid = p.pid)
  ORDER BY
    (p.name = '${process_name}') DESC,
    EXISTS(SELECT 1 FROM thread_state ts WHERE ts.utid = t.utid) DESC,
    t.utid
  LIMIT 1
),
waits AS (
  SELECT t.id AS wait_id, t.ts AS ws, t.ts + t.dur AS we
  FROM thread_state t
  CROSS JOIN main_thread mt
  WHERE t.utid = mt.utid
    AND t.state IN ('S', 'D')
    AND t.dur > ${min_wait_ms|10} * 1000000
    AND t.ts + t.dur > ${start_ts}
    AND t.ts < ${end_ts}
),
top_waits AS (
  SELECT * FROM waits ORDER BY we - ws DESC LIMIT ${top_waits|8}
),
chain AS (
  SELECT w.wait_id, w.ws, w.we, 1 AS depth, r.waker_utid AS hop_utid,
    (SELECT MAX(p0.ts) FROM thread_state p0
     WHERE p0.utid = r.waker_utid AND p0.state IN ('R', 'R+')
       AND p0.waker_utid IS NOT NULL AND p0.ts < r.ts) AS hop_own_wake_ts
  FROM top_waits w
  JOIN thread_state r
    ON r.utid = (SELECT utid FROM main_thread)
    AND r.ts = w.we
    AND r.state IN ('R', 'R+')
    AND r.waker_utid IS NOT NULL
  UNION ALL
  SELECT c.wait_id, c.ws, c.we, c.depth + 1, p.waker_utid AS hop_utid,
    (SELECT MAX(p2.ts) FROM thread_state p2
     WHERE p2.utid = p.waker_utid AND p2.state IN ('R', 'R+')
       AND p2.waker_utid IS NOT NULL AND p2.ts < p.ts) AS hop_own_wake_ts
  FROM chain c
  JOIN thread_state p
    ON p.utid = c.hop_utid
    AND p.ts = c.hop_own_wake_ts
    AND p.state IN ('R', 'R+')
    AND p.waker_utid IS NOT NULL
  WHERE c.depth < ${max_hops|6}
    AND c.hop_own_wake_ts IS NOT NULL
    AND c.hop_own_wake_ts > c.ws
)
SELECT
  printf('%d', c.ws) AS wait_start_ts,
  ROUND((c.we - c.ws) / 1e6, 2) AS wait_ms,
  c.depth AS hop,
  wt.name AS waker_thread_name,
  wp.name AS waker_process_name,
  CASE WHEN c.hop_own_wake_ts IS NOT NULL THEN printf('%d', c.hop_own_wake_ts) END AS waker_runnable_ts,
  ROUND(COALESCE((
    SELECT s.dur / 1e6 FROM thread_state s
    WHERE s.utid = c.hop_utid AND s.state IN ('S', 'D')
      AND s.ts + s.dur = c.hop_own_wake_ts
  ), 0), 2) AS waker_wait_before_ms,
  ROUND((
    SELECT COALESCE(SUM(MIN(r2.ts + r2.dur, c.we) - MAX(r2.ts, c.ws)), 0) / 1e6
    FROM thread_state r2
    WHERE r2.utid = c.hop_utid AND r2.state = 'Running'
      AND r2.ts < c.we AND r2.ts + r2.dur > c.ws
  ), 2) AS run_ms_in_wait,
  CASE
    WHEN c.hop_own_wake_ts IS NULL THEN 'end_no_waker'
    WHEN c.hop_own_wake_ts <= c.ws THEN 'end_root_before_window'
    WHEN c.depth >= ${max_hops|6} THEN 'end_depth_cap'
    ELSE 'relay'
  END AS chain_status
FROM chain c
JOIN thread wt ON wt.utid = c.hop_utid
LEFT JOIN process wp ON wt.upid = wp.upid
ORDER BY (c.we - c.ws) DESC, c.wait_id, c.depth
