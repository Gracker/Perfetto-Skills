-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 6ebd984e1b34cb456d5fa410b4e2308e350c5854086ec1e06ff58b4c80c5ef4f
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
