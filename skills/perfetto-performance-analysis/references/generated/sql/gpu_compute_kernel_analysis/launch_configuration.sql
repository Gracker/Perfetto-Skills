-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_compute_kernel_analysis.skill.yaml
-- Source SHA-256: 04ce0fdb105d89c591b8d24656540615492754eb847da9f8bec211de2a39e9df
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH launches AS (
  SELECT
    s.id,
    ROW_NUMBER() OVER (ORDER BY s.ts, s.id) AS launch_id,
    COALESCE(
      CAST(EXTRACT_ARG(s.arg_set_id, 'kernel_demangled_name') AS TEXT),
      CAST(EXTRACT_ARG(s.arg_set_id, 'kernel_name') AS TEXT),
      s.name
    ) AS kernel,
    EXTRACT_ARG(s.arg_set_id, 'launch.grid_size.x') AS grid_x,
    EXTRACT_ARG(s.arg_set_id, 'launch.grid_size.y') AS grid_y,
    EXTRACT_ARG(s.arg_set_id, 'launch.grid_size.z') AS grid_z,
    EXTRACT_ARG(s.arg_set_id, 'launch.workgroup_size.x') AS workgroup_x,
    EXTRACT_ARG(s.arg_set_id, 'launch.workgroup_size.y') AS workgroup_y,
    EXTRACT_ARG(s.arg_set_id, 'launch.workgroup_size.z') AS workgroup_z,
    EXTRACT_ARG(s.arg_set_id, 'registers_per_thread') AS registers_per_thread,
    EXTRACT_ARG(s.arg_set_id, 'shared_mem_static') AS shared_mem_static_bytes,
    EXTRACT_ARG(s.arg_set_id, 'shared_mem_dynamic') AS shared_mem_dynamic_bytes,
    EXTRACT_ARG(s.arg_set_id, 'barriers_per_block') AS barriers_per_block,
    EXTRACT_ARG(s.arg_set_id, 'waves_per_multiprocessor') AS waves_per_multiprocessor
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
  grid_x,
  grid_y,
  grid_z,
  workgroup_x,
  workgroup_y,
  workgroup_z,
  CASE WHEN workgroup_x > 0 AND workgroup_y > 0 AND workgroup_z > 0
         AND 1.0 * workgroup_x * workgroup_y * workgroup_z <= 9223372036854775807.0
    THEN CAST(workgroup_x * workgroup_y * workgroup_z AS INTEGER) END AS workgroup_threads,
  CASE WHEN grid_x > 0 AND grid_y > 0 AND grid_z > 0
         AND workgroup_x > 0 AND workgroup_y > 0 AND workgroup_z > 0
         AND 1.0 * grid_x * grid_y * grid_z * workgroup_x * workgroup_y * workgroup_z
           <= 9223372036854775807.0
    THEN CAST(grid_x * grid_y * grid_z * workgroup_x * workgroup_y * workgroup_z AS INTEGER)
  END AS total_threads,
  registers_per_thread,
  shared_mem_static_bytes,
  shared_mem_dynamic_bytes,
  barriers_per_block,
  waves_per_multiprocessor
FROM launches
WHERE grid_x IS NOT NULL OR grid_y IS NOT NULL OR grid_z IS NOT NULL
  OR workgroup_x IS NOT NULL OR workgroup_y IS NOT NULL OR workgroup_z IS NOT NULL
  OR registers_per_thread IS NOT NULL OR shared_mem_static_bytes IS NOT NULL
  OR shared_mem_dynamic_bytes IS NOT NULL OR barriers_per_block IS NOT NULL
  OR waves_per_multiprocessor IS NOT NULL
ORDER BY launch_id
LIMIT (SELECT max_rows FROM input)
