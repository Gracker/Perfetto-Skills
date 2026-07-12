-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/lock_contention_in_range.skill.yaml
-- Source SHA-256: 5ab49bd436eb79f8d1bdc21b06e2b662481cb3335728c1776c55c8b0fab0f99b
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH
raw_art_contentions AS (
  SELECT
    printf('art:%d', s.id) AS event_key,
    s.id,
    s.ts,
    s.dur,
    s.name,
    s.utid,
    cast_int!(STR_SPLIT(STR_SPLIT(s.name, '(owner tid: ', 1), ')', 0)) AS owner_tid
  FROM thread_slice AS s
  WHERE s.name GLOB 'Lock contention*(owner tid: *)*'
),
art_contentions AS (
  SELECT
    r.event_key,
    r.id,
    r.ts,
    r.dur,
    p.name AS process_name,
    r.name AS lock_name,
    r.owner_tid,
    owner_thread.utid AS owner_utid,
    blocked_thread.name AS blocked_thread_name,
    owner_thread.name AS blocking_thread_name,
    CASE
      WHEN r.name GLOB '*monitor*' THEN 'monitor'
      WHEN r.name GLOB '*mutex*' THEN 'mutex'
      ELSE 'art_lock'
    END AS lock_type,
    0 AS is_monitor
  FROM raw_art_contentions AS r
  JOIN thread AS blocked_thread
    ON r.utid = blocked_thread.utid
  LEFT JOIN process AS p
    ON blocked_thread.upid = p.upid
  LEFT JOIN thread AS owner_thread
    ON owner_thread.tid = r.owner_tid
    AND (owner_thread.upid = blocked_thread.upid OR r.owner_tid = 0)
  WHERE owner_thread.utid IS NOT NULL
    AND r.dur > 0
),
monitor_contentions AS (
  SELECT
    printf('monitor:%d', id) AS event_key,
    id,
    ts,
    dur,
    process_name,
    COALESCE(short_blocking_method, blocking_method, 'Unknown Lock') AS lock_name,
    blocking_tid AS owner_tid,
    blocking_utid AS owner_utid,
    blocked_thread_name,
    blocking_thread_name,
    'monitor' AS lock_type,
    1 AS is_monitor
  FROM android_monitor_contention
  WHERE blocking_utid IS NOT NULL
    AND dur > 0
),
all_lock_contentions AS (
  SELECT * FROM art_contentions
  UNION ALL
  SELECT * FROM monitor_contentions
),
owner_states AS (
  SELECT
    c.event_key,
    ts.state AS owner_thread_state,
    ts.blocked_function AS owner_blocked_function,
    SUM(MIN(ts.ts + ts.dur, c.ts + c.dur) - MAX(ts.ts, c.ts)) AS owner_state_dur
  FROM all_lock_contentions AS c
  JOIN thread_state AS ts
    ON ts.utid = c.owner_utid
    AND ts.ts < c.ts + c.dur
    AND ts.ts + ts.dur > c.ts
  GROUP BY c.event_key, ts.state, ts.blocked_function
),
ranked_owner_states AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY event_key ORDER BY owner_state_dur DESC) AS rn
  FROM owner_states
)
SELECT
  CASE WHEN c.is_monitor THEN 'monitor_contention' ELSE 'art_lock_contention' END AS source,
  c.process_name,
  c.lock_name,
  c.lock_type,
  c.blocked_thread_name,
  c.blocking_thread_name,
  c.owner_tid,
  COALESCE(ros.owner_thread_state, 'unknown') AS owner_thread_state,
  ros.owner_blocked_function,
  ROUND(c.dur / 1e6, 2) AS wait_ms,
  ROUND(COALESCE(ros.owner_state_dur, 0) / 1e6, 2) AS owner_state_ms
FROM all_lock_contentions AS c
LEFT JOIN ranked_owner_states AS ros
  ON ros.event_key = c.event_key
  AND ros.rn = 1
WHERE c.ts >= ${start_ts}
  AND c.ts < ${end_ts}
  AND (c.process_name GLOB '${package}*' OR '${package}' = '')
  AND c.dur >= 1000000
ORDER BY c.dur DESC
LIMIT 100
