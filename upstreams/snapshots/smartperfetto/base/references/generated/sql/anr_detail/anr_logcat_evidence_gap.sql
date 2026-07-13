-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: e48c73408b2775bed099612d32832cde9f70ca33cd1cc462e0275b1454588359
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  '${error_id}' AS error_id,
  'evidence_unavailable' AS signal_type,
  'missing_source' AS evidence_scope,
  0 AS root_cause_eligible,
  'Trace 缺少 android_logs，无法用 Logcat/AnrManager 校验当前 ANR 触发上下文' AS msg_preview
