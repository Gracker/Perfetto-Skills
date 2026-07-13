-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

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
