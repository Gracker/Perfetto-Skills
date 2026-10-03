-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: 608783942f2db1a99117105e5d2d95faddd0b3074bd5cfdc5ad464f383ec5280

SELECT
  'no_gpu_v57_activity_or_frequency_rows' AS status,
  gpu_rows,
  gpu_activity_rows,
  gpufreq_tracks
FROM ${data_check}
