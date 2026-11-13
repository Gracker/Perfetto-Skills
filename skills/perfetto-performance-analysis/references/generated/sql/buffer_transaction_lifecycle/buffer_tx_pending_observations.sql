-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/buffer_transaction_lifecycle.skill.yaml
-- Source SHA-256: 977f9ee7b1e356090321193837d29dbd067b40b9ba43929e9c297508292d5421

WITH samples_with_previous AS (
  SELECT c.id, c.track_id, ct.name AS track_name, c.ts, c.value,
    LAG(c.value) OVER (PARTITION BY c.track_id ORDER BY c.ts, c.id) AS previous_value
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE ct.name GLOB 'BufferTX - *'
    AND c.ts < ${end_ts}
    AND ('${package|}' = '' OR (
      INSTR(ct.name, '${package|}') > 0
      AND (INSTR(ct.name, '${package|}') = 1
        OR SUBSTR(ct.name, INSTR(ct.name, '${package|}') - 1, 1) IN (' ', '[', '(', ':', '/', '-'))
      AND (INSTR(ct.name, '${package|}') + LENGTH('${package|}') > LENGTH(ct.name)
        OR SUBSTR(ct.name, INSTR(ct.name, '${package|}') + LENGTH('${package|}'), 1)
          IN ('/', ':', '#', ']', ')', ' '))
    ))
),
window_samples AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY track_id ORDER BY ts DESC, id DESC) AS reverse_index
  FROM samples_with_previous
  WHERE ts >= ${start_ts}
)
SELECT
  track_id, track_name, COUNT(*) AS sample_count,
  SUM(CASE WHEN value > previous_value THEN CAST(value - previous_value AS INTEGER) ELSE 0 END) AS received_updates,
  SUM(CASE WHEN value < previous_value THEN CAST(previous_value - value AS INTEGER) ELSE 0 END) AS removed_updates,
  MIN(value) AS min_pending_updates,
  MAX(value) AS max_pending_updates,
  MAX(CASE WHEN reverse_index = 1 THEN value END) AS last_pending_updates,
  CASE WHEN COUNT(previous_value) < COUNT(*) THEN 'partial_missing_previous_sample'
    ELSE 'observed' END AS coverage_status,
  CASE WHEN '${package|}' = '' THEN 'all_matching_counter_tracks'
    ELSE 'package_layer_name_match_not_exact_upid' END AS evidence_scope,
  'server_pending_not_gpu_ready_or_presented_frames' AS claim_boundary
FROM window_samples
GROUP BY track_id, track_name
UNION ALL
SELECT NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL,
  'unavailable_no_counter_samples',
  CASE WHEN '${package|}' = '' THEN 'all_matching_counter_tracks'
    ELSE 'package_layer_name_match_not_exact_upid' END,
  'server_pending_not_gpu_ready_or_presented_frames'
WHERE NOT EXISTS (SELECT 1 FROM window_samples)
ORDER BY track_id
