-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_hot_slice_states.skill.yaml
-- Source SHA-256: bd287fdd71c8bd1a0b349bca9db78b6080a78cc9d1ba3751a94e558c6a04f264
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH main_thread AS (
  SELECT t.utid, p.pid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*'
    AND t.tid = p.pid
),
hot_slices AS (
  SELECT
    s.name as slice_name,
    s.ts as slice_ts,
    s.ts + s.dur as slice_end,
    s.dur / 1e6 as slice_dur_ms
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN main_thread mt ON tt.utid = mt.utid
  WHERE s.ts >= ${start_ts}
    AND s.ts + s.dur <= ${end_ts}
    AND s.dur >= 5000000
  ORDER BY s.dur DESC
  LIMIT ${top_n|10}
)
SELECT
  hs.slice_name,
  ROUND(hs.slice_dur_ms, 1) as slice_dur_ms,
  printf('%d', hs.slice_ts) as slice_ts,
  tstate.state,
  COALESCE(tstate.io_wait, 0) as io_wait,
  ROUND(SUM(
    MIN(tstate.ts + tstate.dur, hs.slice_end) - MAX(tstate.ts, hs.slice_ts)
  ) / 1e6, 2) as state_dur_ms,
  ROUND(100.0 * SUM(
    MIN(tstate.ts + tstate.dur, hs.slice_end) - MAX(tstate.ts, hs.slice_ts)
  ) / (hs.slice_dur_ms * 1e6), 1) as state_pct,
  CASE
    WHEN tstate.state IN ('D', 'DK') AND COALESCE(tstate.io_wait, 0) = 1 THEN 'direct_io_wait'
    WHEN tstate.state IN ('D', 'DK') AND (
      LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%filemap%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%page_fault%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%wait_on_page%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%folio_wait%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%io_schedule%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%submit_bio%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%blk_%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%ext4%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%f2fs%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%erofs%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%ufshcd%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%mmc_%'
      OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%dm_%'
    ) THEN 'inferred_io_or_page_cache'
    WHEN tstate.state IN ('D', 'DK') THEN 'ambiguous_uninterruptible_wait'
    WHEN tstate.state = 'S' AND (LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%epoll%' OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%poll%') THEN 'poll_idle_or_ambiguous'
    WHEN tstate.state = 'S' AND (LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%futex%' OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%mutex%' OR LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%monitor%') THEN 'lock_wait'
    WHEN LOWER(COALESCE(tstate.blocked_function, '')) LIKE '%binder%' THEN 'binder_wait'
    ELSE 'state_only'
  END as evidence_strength,
  COALESCE(NULLIF(tstate.blocked_function, ''), '-') as blocked_functions
FROM hot_slices hs
JOIN main_thread mt
JOIN thread_state tstate ON tstate.utid = mt.utid
  AND tstate.ts < hs.slice_end
  AND tstate.ts + tstate.dur > hs.slice_ts
GROUP BY hs.slice_name, hs.slice_ts, tstate.state, COALESCE(tstate.io_wait, 0), tstate.blocked_function
ORDER BY hs.slice_dur_ms DESC, state_dur_ms DESC
