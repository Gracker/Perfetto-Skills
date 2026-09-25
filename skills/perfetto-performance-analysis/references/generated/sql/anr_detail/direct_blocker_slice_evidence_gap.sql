-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 69869c165513d6e975cde75d83230b412b1276132fd888e9d2fbf6a898cc2db3
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

SELECT
  'slice_evidence_unavailable' AS direct_blocker_type,
  0 AS evidence_ms,
  0 AS pct_of_timeout,
  'missing_thread_track_or_slice' AS evidence_source,
  'low' AS confidence,
  'missing_slice_evidence' AS root_cause_boundary,
  'Trace 缺少 thread_track/slice，无法从主线程或 RenderThread slice 判断 IO/GC/渲染候选；thread_state 直接阻塞点仍可使用' AS next_evidence_needed
