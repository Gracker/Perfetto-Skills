-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_compute_kernel_analysis.skill.yaml
-- Source SHA-256: 04ce0fdb105d89c591b8d24656540615492754eb847da9f8bec211de2a39e9df
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH kernels AS (
  SELECT
    s.id,
    s.ts,
    s.dur,
    ROW_NUMBER() OVER (ORDER BY s.ts, s.id) AS launch_id,
    IFNULL(EXTRACT_ARG(t.dimension_arg_set_id, 'ugpu'), 0) AS ugpu,
    COALESCE(
      CAST(EXTRACT_ARG(s.arg_set_id, 'kernel_demangled_name') AS TEXT),
      CAST(EXTRACT_ARG(s.arg_set_id, 'kernel_name') AS TEXT),
      s.name
    ) AS kernel
  FROM gpu_slice AS s
  JOIN gpu_track AS t ON s.track_id = t.id
  WHERE s.render_stage_category = 2
    AND s.dur > 0
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
    AND (${ugpu} IS NULL OR IFNULL(EXTRACT_ARG(t.dimension_arg_set_id, 'ugpu'), 0) = ${ugpu})
),
input AS (
  SELECT MIN(MAX(COALESCE(${max_rows|50}, 50), 1), 200) AS max_rows
)
SELECT
  launch_id,
  kernel,
  ugpu,
  printf('%d', ts) AS ts,
  dur AS dur_ns,
  ROUND(100.0 * dur / NULLIF(SUM(dur) OVER (), 0), 2) AS compute_time_pct
FROM kernels
ORDER BY dur_ns DESC, launch_id
LIMIT (SELECT max_rows FROM input)
