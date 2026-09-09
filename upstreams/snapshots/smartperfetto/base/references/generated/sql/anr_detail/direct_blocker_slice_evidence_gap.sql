-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 283e74c341c76d3959624287f046bcc7f85e2b7b1cbe1edfab07c544a01660af
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  'slice_evidence_unavailable' AS direct_blocker_type,
  0 AS evidence_ms,
  0 AS pct_of_timeout,
  'missing_thread_track_or_slice' AS evidence_source,
  'low' AS confidence,
  'missing_slice_evidence' AS root_cause_boundary,
  'Trace 缺少 thread_track/slice，无法从主线程或 RenderThread slice 判断 IO/GC/渲染候选；thread_state 直接阻塞点仍可使用' AS next_evidence_needed
