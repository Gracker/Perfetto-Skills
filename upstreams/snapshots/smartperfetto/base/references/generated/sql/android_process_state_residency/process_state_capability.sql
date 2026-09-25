-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_process_state_residency.skill.yaml
-- Source SHA-256: f785279fb41abf9e40451b7089d02655c17180229724e8a28759af866c6347cf
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH facts AS (
  SELECT
    EXISTS (
      SELECT 1 FROM pragma_table_info('__intrinsic_android_process_state')
    ) AS runtime_has_process_state_table,
    EXISTS (
      SELECT 1 FROM sqlite_master WHERE name = '_android_process_state_intervals'
    ) AS runtime_has_process_state_module
)
SELECT
  runtime_has_process_state_table,
  runtime_has_process_state_module,
  CASE
    WHEN NOT runtime_has_process_state_table THEN 'runtime_lacks_process_state'
    WHEN NOT runtime_has_process_state_module THEN 'runtime_lacks_process_state_module'
    ELSE 'runtime_supported'
  END AS status
FROM facts
