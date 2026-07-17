-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: e48c73408b2775bed099612d32832cde9f70ca33cd1cc462e0275b1454588359
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

SELECT
  'slice_evidence_unavailable' AS direct_blocker_type,
  0 AS evidence_ms,
  0 AS pct_of_timeout,
  'missing_thread_track_or_slice' AS evidence_source,
  'low' AS confidence,
  'missing_slice_evidence' AS root_cause_boundary,
  'Trace 缺少 thread_track/slice，无法从主线程或 RenderThread slice 判断 IO/GC/渲染候选；thread_state 直接阻塞点仍可使用' AS next_evidence_needed
