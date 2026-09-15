-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 8f9a0954db22c1fcbcbb1d90da0bb15de24e08b37ba60f59c45fb99fa915eb4b
-- Source commit: 00559cb4068232b511e24c614eadcad0b122bdc5

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
