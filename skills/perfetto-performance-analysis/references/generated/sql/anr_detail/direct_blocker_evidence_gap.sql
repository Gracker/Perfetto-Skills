-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 69869c165513d6e975cde75d83230b412b1276132fd888e9d2fbf6a898cc2db3
-- Source commit: bc007586871a720aed82537913617c64fb95a459

SELECT
  'evidence_unavailable' AS direct_blocker_type,
  0 AS evidence_ms,
  0 AS pct_of_timeout,
  'missing_thread_state' AS evidence_source,
  'low' AS confidence,
  'missing_thread_state_evidence' AS root_cause_boundary,
  'Trace 缺少 thread_state，无法从主线程状态判断直接阻塞点；只能保留 trigger/logcat 为上下文证据' AS next_evidence_needed
