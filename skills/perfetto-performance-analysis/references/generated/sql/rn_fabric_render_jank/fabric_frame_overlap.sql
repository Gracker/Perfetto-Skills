-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rn_fabric_render_jank.skill.yaml
-- Source SHA-256: fdfb43f4d0487f058bf09549e6a0be4d373503cd106e5e8344e77129265ead8a
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

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
fabric_slices AS (
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
      WHEN s.name GLOB '*Fabric*' OR s.name GLOB '*SurfaceMountingManager*' OR s.name GLOB '*executeMount*' OR s.name GLOB '*MountItem*' THEN 'fabric_mounting'
      WHEN s.name GLOB '*ShadowTree*' THEN 'shadow_tree_commit'
      WHEN s.name GLOB '*JSI*' THEN 'jsi_sync'
      WHEN s.name GLOB '*TurboModule*' THEN 'turbo_module'
      WHEN s.name GLOB '*Reanimated*' THEN 'reanimated'
      ELSE 'rn_new_arch'
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
      s.name GLOB '*Fabric*' OR s.name GLOB '*SurfaceMountingManager*' OR
      s.name GLOB '*executeMount*' OR s.name GLOB '*MountItem*' OR s.name GLOB '*ShadowTree*' OR
      s.name GLOB '*JSI*' OR s.name GLOB '*TurboModule*' OR s.name GLOB '*Reanimated*' OR
      t.name GLOB '*mqt_native_modules*'
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
    fs.*,
    f.frame_id,
    f.dur AS frame_dur,
    f.jank_type,
    MAX(0, MIN(fs.ts_end, f.ts_end) - MAX(fs.ts, f.ts)) AS overlap_ns
  FROM fabric_slices fs
  JOIN frames f ON f.upid = fs.upid
    AND fs.ts < f.ts_end
    AND fs.ts_end > f.ts
)
SELECT
  printf('%d', ts) AS ts,
  printf('%d', dur) AS dur_ns,
  ROUND(dur / 1e6, 2) AS dur_ms,
  phase,
  slice_name,
  thread_name,
  process_name,
  COUNT(DISTINCT frame_id) AS overlapped_frames,
  SUM(CASE WHEN jank_type != 'None' OR frame_dur > (SELECT budget_ns * 1.5 FROM frame_budget) THEN 1 ELSE 0 END) AS janky_frames,
  ROUND(MAX(overlap_ns) / 1e6, 2) AS max_overlap_ms,
  CASE
    WHEN dur > (SELECT budget_ns * 2 FROM frame_budget) AND SUM(CASE WHEN jank_type != 'None' OR frame_dur > (SELECT budget_ns * 1.5 FROM frame_budget) THEN 1 ELSE 0 END) > 0 THEN 'critical'
    WHEN dur > (SELECT budget_ns FROM frame_budget) THEN 'warning'
    ELSE 'notice'
  END AS severity
FROM overlaps
WHERE overlap_ns > 0
GROUP BY id, ts, dur, phase, slice_name, thread_name, process_name
HAVING janky_frames > 0 OR dur_ms > 8
ORDER BY janky_frames DESC, dur_ms DESC
LIMIT 100
