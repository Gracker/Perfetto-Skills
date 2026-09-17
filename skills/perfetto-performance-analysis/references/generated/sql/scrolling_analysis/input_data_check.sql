-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 7c73e3893771fc262f7afad100bd5963d65ee2afe54b8bd139a0cf95e9c82eb8
-- Source commit: e198ac39082cf1b029b0833e46e8ee49dd9387ce

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
