-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 5373394d55d3a035fc472bc4f0684c504581b9760f01a90d2c596cd88d35f92e

SELECT
  '${error_id}' AS error_id,
  'evidence_unavailable' AS signal_type,
  'missing_source' AS evidence_scope,
  0 AS root_cause_eligible,
  'Trace 缺少 android_logs，无法用 Logcat/AnrManager 校验当前 ANR 触发上下文' AS msg_preview
