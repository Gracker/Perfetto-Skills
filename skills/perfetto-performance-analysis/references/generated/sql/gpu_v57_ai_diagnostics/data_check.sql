-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: ac78ea2ed81bd2cff026d28c2ff54159ddd20e792fccc6cbd00171f1b18c6a36
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT
  (SELECT COUNT(*) FROM gpu) AS gpu_rows,
  (SELECT COUNT(*) FROM gpu_slice WHERE dur > 0) AS gpu_activity_rows,
  (SELECT COUNT(*) FROM gpu_counter_track WHERE name = 'gpufreq') AS gpufreq_tracks,
  CASE WHEN EXISTS (SELECT 1 FROM pragma_table_info('gpu') WHERE name = 'machine_id') THEN 1 ELSE 0 END AS has_gpu_machine_id,
  CASE WHEN EXISTS (SELECT 1 FROM pragma_table_info('gpu') WHERE name = 'architecture') THEN 1 ELSE 0 END AS has_gpu_architecture,
  CASE WHEN EXISTS (SELECT 1 FROM pragma_table_info('gpu_counter_track') WHERE name = 'ugpu') THEN 1 ELSE 0 END AS has_gpu_counter_ugpu,
  CASE WHEN EXISTS (SELECT 1 FROM pragma_table_info('gpu_track') WHERE name = 'dimension_arg_set_id') THEN 1 ELSE 0 END AS has_gpu_track_dimensions
