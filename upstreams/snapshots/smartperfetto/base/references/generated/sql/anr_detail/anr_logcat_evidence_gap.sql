-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 283e74c341c76d3959624287f046bcc7f85e2b7b1cbe1edfab07c544a01660af
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  '${error_id}' AS error_id,
  'evidence_unavailable' AS signal_type,
  'missing_source' AS evidence_scope,
  0 AS root_cause_eligible,
  'Trace 缺少 android_logs，无法用 Logcat/AnrManager 校验当前 ANR 触发上下文' AS msg_preview
