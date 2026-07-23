-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_compute_kernel_analysis.skill.yaml
-- Source SHA-256: 04ce0fdb105d89c591b8d24656540615492754eb847da9f8bec211de2a39e9df
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH compute_rows AS (
  SELECT s.arg_set_id
  FROM gpu_slice AS s
  JOIN gpu_track AS t ON s.track_id = t.id
  WHERE s.render_stage_category = 2
    AND s.dur > 0
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
    AND (${ugpu} IS NULL OR IFNULL(EXTRACT_ARG(t.dimension_arg_set_id, 'ugpu'), 0) = ${ugpu})
)
SELECT
  COUNT(*) AS compute_rows,
  SUM(CASE WHEN
    EXTRACT_ARG(arg_set_id, 'launch.grid_size.x') IS NOT NULL
    OR EXTRACT_ARG(arg_set_id, 'launch.grid_size.y') IS NOT NULL
    OR EXTRACT_ARG(arg_set_id, 'launch.grid_size.z') IS NOT NULL
    OR EXTRACT_ARG(arg_set_id, 'launch.workgroup_size.x') IS NOT NULL
    OR EXTRACT_ARG(arg_set_id, 'launch.workgroup_size.y') IS NOT NULL
    OR EXTRACT_ARG(arg_set_id, 'launch.workgroup_size.z') IS NOT NULL
    OR EXTRACT_ARG(arg_set_id, 'registers_per_thread') IS NOT NULL
    OR EXTRACT_ARG(arg_set_id, 'shared_mem_static') IS NOT NULL
    OR EXTRACT_ARG(arg_set_id, 'shared_mem_dynamic') IS NOT NULL
    OR EXTRACT_ARG(arg_set_id, 'barriers_per_block') IS NOT NULL
    OR EXTRACT_ARG(arg_set_id, 'waves_per_multiprocessor') IS NOT NULL
    THEN 1 ELSE 0 END) AS launch_arg_rows
FROM compute_rows
