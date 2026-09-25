-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/frame_blocking_calls.skill.yaml
-- Source SHA-256: f50aec9da16055b40141764cc3668c04f17cc70cceddcf65c2cff8c9ae89a062
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH jank_frames AS (
  SELECT
    a.display_frame_token as frame_id,
    a.ts as frame_ts,
    a.dur as frame_dur,
    a.ts + a.dur as frame_end,
    a.jank_type
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
    AND COALESCE(a.jank_type, 'None') != 'None'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
),
-- Note: _android_critical_blocking_calls is an internal Perfetto stdlib table (underscore prefix).
-- It is widely used within the Perfetto codebase and is stable in practice.
-- No public equivalent exists without RUN_METRIC.
blocking AS (
  SELECT
    bc.name as blocking_call,
    bc.ts as call_ts,
    bc.dur as call_dur,
    bc.process_name as call_process,
    bc.utid,
    COALESCE(t.name, 'unknown') as thread_name,
    CASE
      WHEN t.tid = p.pid THEN 'MainThread'
      WHEN t.name = 'RenderThread' OR t.name GLOB '*RenderThread*' THEN 'RenderThread'
      WHEN t.name GLOB 'Binder:*' OR t.name GLOB '*Binder*' THEN 'BinderThread'
      ELSE 'Other'
    END as thread_role
  FROM _android_critical_blocking_calls bc
  LEFT JOIN thread t ON t.utid = bc.utid
  LEFT JOIN process p ON p.upid = bc.upid
  WHERE ('${process_name}' = '' OR bc.process_name = '${process_name}' OR bc.process_name GLOB '${process_name}:*')
)
SELECT
  printf('%d', jf.frame_id) as frame_id,
  printf('%d', jf.frame_ts) as frame_ts,
  ROUND(jf.frame_dur / 1e6, 2) as frame_dur_ms,
  jf.jank_type,
  b.thread_role,
  b.thread_name,
  b.blocking_call,
  ROUND(
    (MIN(b.call_ts + b.call_dur, jf.frame_end) - MAX(b.call_ts, jf.frame_ts)) / 1e6,
    2
  ) as overlap_ms,
  ROUND(b.call_dur / 1e6, 2) as call_dur_ms,
  COUNT(*) as call_count
FROM jank_frames jf
JOIN blocking b
  ON b.call_ts < jf.frame_end
  AND b.call_ts + b.call_dur > jf.frame_ts
GROUP BY jf.frame_id, b.thread_role, b.thread_name, b.blocking_call
HAVING overlap_ms > 0.5
ORDER BY jf.frame_ts, overlap_ms DESC
LIMIT 100
