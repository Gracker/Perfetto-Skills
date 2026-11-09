-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/systemui_module.skill.yaml
-- Source SHA-256: 7bad353475730c50d78e32f5389eef8a18f13d37f2838d318c9d9bfe0c0a577a

SELECT
  p.upid,
  p.pid,
  p.name AS process_name
FROM process p
WHERE p.name LIKE '%systemui%'
  OR p.name LIKE '%SystemUI%'
  OR p.name = 'com.android.systemui'
LIMIT 1
