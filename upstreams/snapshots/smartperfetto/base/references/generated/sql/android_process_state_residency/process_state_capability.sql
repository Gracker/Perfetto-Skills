-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_process_state_residency.skill.yaml
-- Source SHA-256: 226abdc8bd617a35c5005014a5020538455aa88290a2d96fa911645bbb2387b1

WITH facts AS (
  SELECT
    EXISTS (
      SELECT 1 FROM pragma_table_info('__intrinsic_android_process_state')
    ) AS runtime_has_process_state_table,
    EXISTS (
      SELECT 1 FROM sqlite_master WHERE name = '_android_process_state_intervals'
    ) AS runtime_has_process_state_module,
    (SELECT COUNT(*) FROM pragma_table_info('_android_process_state_intervals')
      WHERE name IN ('state_change_reason', 'hosting_type', 'hosting_name',
        'trigger_type', 'bind_application_delay_ms', 'process_start_delay_ms',
        'exit_reason', 'exit_subreason')) = 8 AS runtime_has_process_lifecycle
)
SELECT
  runtime_has_process_state_table,
  runtime_has_process_state_module,
  CASE
    WHEN NOT runtime_has_process_state_table THEN 'runtime_lacks_process_state'
    WHEN NOT runtime_has_process_state_module THEN 'runtime_lacks_process_state_module'
    WHEN NOT runtime_has_process_lifecycle THEN 'runtime_lacks_process_lifecycle'
    ELSE 'runtime_supported'
  END AS status
FROM facts
