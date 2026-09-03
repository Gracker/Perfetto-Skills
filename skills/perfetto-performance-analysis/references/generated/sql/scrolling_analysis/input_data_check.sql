-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 898b631aafbdad1f8c7fabc5e2a741fa750cf701ec82b9810adfd3e687b94431
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH scoped_events AS (
  SELECT *
  FROM android_input_events
  WHERE (
    '${package}' = ''
    OR process_name = '${package}'
    OR process_name GLOB '${package}:*'
  )
    AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
)
SELECT
  CASE
    WHEN COUNT(*) = 0 THEN 'unavailable'
    WHEN COALESCE(SUM(CASE WHEN frame_id IS NOT NULL THEN 1 ELSE 0 END), 0) = 0 THEN 'no_frame_match'
    ELSE 'available'
  END as input_data_status,
  COUNT(*) as total_input_events,
  COALESCE(SUM(CASE WHEN event_action = 'MOVE' THEN 1 ELSE 0 END), 0) as move_events,
  COALESCE(SUM(CASE WHEN frame_id IS NOT NULL THEN 1 ELSE 0 END), 0) as frame_matched_events,
  COUNT(DISTINCT process_name) as target_processes
FROM scoped_events
