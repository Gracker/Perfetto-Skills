-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_load_in_range.skill.yaml
-- Source SHA-256: 71e2b4436e6f0eb4a11f04bf71bfc3a9703ee7c738fb37d8ddf20f67ec7bc955
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  t.cpu,
  COALESCE(ct.core_type, 'unknown') as core_type,
  ROUND(AVG(c.value), 2) as avg_runqueue,
  MAX(c.value) as max_runqueue
FROM counter c
JOIN cpu_counter_track t ON c.track_id = t.id
LEFT JOIN _cpu_topology ct ON t.cpu = ct.cpu_id
WHERE t.name = 'runqueue_length'
  AND c.ts >= ${start_ts}
  AND c.ts < ${end_ts}
GROUP BY t.cpu
ORDER BY t.cpu
