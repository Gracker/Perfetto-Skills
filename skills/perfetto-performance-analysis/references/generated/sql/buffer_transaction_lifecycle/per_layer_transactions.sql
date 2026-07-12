-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/buffer_transaction_lifecycle.skill.yaml
-- Source SHA-256: 9bd45c1ab88d6a908b1cc3212e0851489d75932736c4544a9bec8983237545b2
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

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
    OR (layer_name GLOB '*' || '${package}' || '*')
  )
GROUP BY layer_name
ORDER BY frame_count DESC
LIMIT 20
