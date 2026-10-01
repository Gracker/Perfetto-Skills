-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 0be84fe96c0f5e4646a49f1630ef4cfcf6662638c5c42718b3bff9307513577f

SELECT
  '${error_id}' AS error_id,
  'evidence_unavailable' AS signal_type,
  'missing_source' AS evidence_scope,
  0 AS root_cause_eligible,
  'Trace 缺少 android_logs，无法用 Logcat/AnrManager 校验当前 ANR 触发上下文' AS msg_preview
