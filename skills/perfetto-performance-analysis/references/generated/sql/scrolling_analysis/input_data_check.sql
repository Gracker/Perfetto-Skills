-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 2dcba698d9cc63e045e9346afc44cab60148cf55a58161bf0378383d624af4ff
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

WITH scoped_events AS (
  SELECT *
  FROM android_input_events
  WHERE (${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid})
    AND (
    ${__process_scope.upid} IS NOT NULL OR '${package}' = ''
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
  COUNT(DISTINCT upid) as target_processes
FROM scoped_events
