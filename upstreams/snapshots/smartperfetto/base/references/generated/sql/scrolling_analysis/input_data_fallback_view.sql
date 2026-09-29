-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 4007035c487eb410a43fdb6bf3aae3bc1b3bad006e40395f80a69f43bd269da5
-- Source commit: 12f4004d5cdc2aeac76d3afce68ef2e3e87d500f

CREATE VIEW IF NOT EXISTS android_input_events AS
SELECT
  CAST(NULL AS INTEGER) as dispatch_latency_dur,
  CAST(NULL AS INTEGER) as handling_latency_dur,
  CAST(NULL AS INTEGER) as ack_latency_dur,
  CAST(NULL AS INTEGER) as total_latency_dur,
  CAST(NULL AS INTEGER) as end_to_end_latency_dur,
  CAST(NULL AS INTEGER) as tid,
  CAST(NULL AS TEXT) as thread_name,
  CAST(NULL AS INTEGER) as upid,
  CAST(NULL AS INTEGER) as pid,
  CAST(NULL AS TEXT) as process_name,
  CAST(NULL AS TEXT) as event_type,
  CAST(NULL AS TEXT) as event_action,
  CAST(NULL AS INTEGER) as event_seq,
  CAST(NULL AS TEXT) as event_channel,
  CAST(NULL AS TEXT) as normalized_event_channel,
  CAST(NULL AS INTEGER) as input_event_id,
  CAST(NULL AS INTEGER) as read_time,
  CAST(NULL AS INTEGER) as dispatch_track_id,
  CAST(NULL AS INTEGER) as dispatch_ts,
  CAST(NULL AS INTEGER) as dispatch_dur,
  CAST(NULL AS INTEGER) as receive_track_id,
  CAST(NULL AS INTEGER) as receive_ts,
  CAST(NULL AS INTEGER) as receive_dur,
  CAST(NULL AS INTEGER) as frame_id,
  CAST(NULL AS INTEGER) as is_speculative_frame,
  CAST(NULL AS INTEGER) as event_time
WHERE 0
