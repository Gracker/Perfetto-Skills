-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rn_bridge_to_frame_jank.skill.yaml
-- Source SHA-256: d2cce13360dd218d1931638ebf4d69f3b01a43c9ae5c3470bb7c9ba5e3202311
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM slice)) AS end_ts
),
frame_budget AS (
  SELECT COALESCE(
    (SELECT CAST(PERCENTILE(dur, 0.5) AS INTEGER)
     FROM actual_frame_timeline_slice
     WHERE dur BETWEEN 5000000 AND 50000000),
    16666667
  ) AS budget_ns
),
rn_slices AS (
  SELECT
    s.id,
    s.ts,
    s.dur,
    s.ts + s.dur AS ts_end,
    s.name AS slice_name,
    t.name AS thread_name,
    p.name AS process_name,
    p.upid,
    CASE
      WHEN t.name GLOB '*mqt_js*' OR t.name GLOB '*JS*' OR s.name GLOB '*BatchedBridge*' THEN 'js_bridge'
      WHEN s.name GLOB '*UIManager*' OR s.name GLOB '*dispatchViewUpdates*' THEN 'ui_manager'
      WHEN s.name GLOB '*RCTEventEmitter*' OR s.name GLOB '*callFunctionReturnFlushedQueue*' THEN 'bridge_dispatch'
      WHEN s.name GLOB '*ReactChoreographer*' THEN 'react_choreographer'
      ELSE 'rn_old_arch'
    END AS phase
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
    AND s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND s.dur > 0
    AND (
      t.name GLOB '*mqt_js*' OR t.name GLOB '*mqt_native_modules*' OR t.name GLOB '*JS*' OR
      s.name GLOB '*BatchedBridge*' OR s.name GLOB '*callFunctionReturnFlushedQueue*' OR
      s.name GLOB '*UIManager*' OR s.name GLOB '*dispatchViewUpdates*' OR
      s.name GLOB '*RCTEventEmitter*' OR s.name GLOB '*ReactChoreographer*'
    )
),
frames AS (
  SELECT
    a.ts,
    a.dur,
    a.ts + a.dur AS ts_end,
    COALESCE(a.display_frame_token, a.surface_frame_token) AS frame_id,
    COALESCE(a.jank_type, 'None') AS jank_type,
    a.upid
  FROM actual_frame_timeline_slice a
  JOIN process p ON a.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
    AND a.ts >= i.start_ts
    AND a.ts < i.end_ts
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
overlaps AS (
  SELECT
    rs.*,
    f.frame_id,
    f.dur AS frame_dur,
    f.jank_type,
    MAX(0, MIN(rs.ts_end, f.ts_end) - MAX(rs.ts, f.ts)) AS overlap_ns
  FROM rn_slices rs
  JOIN frames f ON f.upid = rs.upid
    AND rs.ts < f.ts_end
    AND rs.ts_end > f.ts
)
SELECT
  printf('%d', ts) AS ts,
  printf('%d', dur) AS dur_ns,
  ROUND(dur / 1e6, 2) AS bridge_dur_ms,
  phase,
  slice_name,
  thread_name,
  process_name,
  COUNT(DISTINCT frame_id) AS overlapped_frames,
  SUM(CASE WHEN jank_type != 'None' OR frame_dur > (SELECT budget_ns * 1.5 FROM frame_budget) THEN 1 ELSE 0 END) AS janky_frames,
  ROUND(MAX(overlap_ns) / 1e6, 2) AS max_overlap_ms,
  ROUND(MAX(frame_dur) / 1e6, 2) AS max_frame_dur_ms
FROM overlaps
WHERE overlap_ns > 0
GROUP BY id, ts, dur, phase, slice_name, thread_name, process_name
HAVING janky_frames > 0 OR bridge_dur_ms > 8
ORDER BY janky_frames DESC, bridge_dur_ms DESC
LIMIT 100
