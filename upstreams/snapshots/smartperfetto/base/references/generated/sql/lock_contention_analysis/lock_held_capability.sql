-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 2218440cfc32dab82a764464dea62719d04148dbaff34657cbe3590d4a063523
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

-- Lock holds are traced in the process that owns the lock (usually
-- system_server), so a process_name filter can leave none in scope even
-- when the trace has them; that is reported, not shown as "no holds".
WITH held AS (
  SELECT process_name FROM thread_slice WHERE name GLOB '*_lock_held'
),
facts AS (
  SELECT
    (SELECT COUNT(*) FROM held) AS lock_held_slice_count,
    (
      SELECT COUNT(*) FROM held
      WHERE '${process_name}' = '' OR process_name GLOB '*${process_name}*'
    ) AS lock_held_slice_count_in_scope,
    EXISTS (
      SELECT 1 FROM sqlite_master WHERE name = 'android_lock_held'
    ) AS runtime_has_lock_held
)
SELECT
  lock_held_slice_count,
  lock_held_slice_count_in_scope,
  runtime_has_lock_held,
  CASE
    WHEN lock_held_slice_count = 0 THEN 'no_lock_held_slices'
    WHEN lock_held_slice_count_in_scope = 0 THEN 'no_lock_held_slices_for_process'
    WHEN NOT runtime_has_lock_held THEN 'runtime_lacks_android_lock_held'
    ELSE 'available'
  END AS status
FROM facts
