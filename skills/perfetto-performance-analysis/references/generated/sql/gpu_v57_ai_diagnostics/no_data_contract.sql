-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: ac78ea2ed81bd2cff026d28c2ff54159ddd20e792fccc6cbd00171f1b18c6a36
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

SELECT
  'no_gpu_v57_activity_or_frequency_rows' AS status,
  gpu_rows,
  gpu_activity_rows,
  gpufreq_tracks
FROM ${data_check}
