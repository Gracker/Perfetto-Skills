-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 283e74c341c76d3959624287f046bcc7f85e2b7b1cbe1edfab07c544a01660af
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  'evidence_unavailable' AS direct_blocker_type,
  0 AS evidence_ms,
  0 AS pct_of_timeout,
  'missing_thread_state' AS evidence_source,
  'low' AS confidence,
  'missing_thread_state_evidence' AS root_cause_boundary,
  'Trace 缺少 thread_state，无法从主线程状态判断直接阻塞点；只能保留 trigger/logcat 为上下文证据' AS next_evidence_needed
