-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/buffer_transaction_lifecycle.skill.yaml
-- Source SHA-256: 38cb7cb1b6874a31a2da8e82406e81c04fade5230ec56e948f7bfd2539a6a85b

SELECT
  layer_name,
  COUNT(*) as frame_count,
  SUM(CASE WHEN jank_type IS NOT NULL AND jank_type != 'None' THEN 1 ELSE 0 END) as jank_count,
  ROUND(AVG(dur) / 1e6, 2) as avg_dur_ms
FROM actual_frame_timeline_slice
WHERE ts >= ${start_ts} AND ts < ${end_ts}
  AND layer_name IS NOT NULL
  AND (
    ('${package}' = '')
    OR instr(layer_name, '${package}') > 0
  )
GROUP BY layer_name
ORDER BY frame_count DESC
LIMIT 20
