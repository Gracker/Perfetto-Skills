-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/buffer_transaction_lifecycle.skill.yaml
-- Source SHA-256: 977f9ee7b1e356090321193837d29dbd067b40b9ba43929e9c297508292d5421

SELECT
  f.upid,
  p.name AS process_name,
  f.layer_name,
  COUNT(*) AS frame_count,
  SUM(CASE WHEN f.jank_type IS NOT NULL AND f.jank_type != 'None' THEN 1 ELSE 0 END) AS jank_count,
  ROUND(AVG(f.dur) / 1e6, 2) AS avg_dur_ms,
  'frame_timeline_layer_records_not_transactions' AS evidence_scope
FROM actual_frame_timeline_slice f
LEFT JOIN process p ON f.upid = p.upid
WHERE f.ts >= ${start_ts} AND f.ts < ${end_ts}
  AND f.dur >= 0
  AND f.layer_name IS NOT NULL
  AND ('${package|}' = '' OR p.name = '${package|}'
    OR SUBSTR(p.name, 1, LENGTH('${package|}') + 1) = '${package|}:')
GROUP BY f.upid, p.name, f.layer_name
ORDER BY frame_count DESC, f.upid, f.layer_name
LIMIT 20
