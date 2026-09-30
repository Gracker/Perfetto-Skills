-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/systemui_module.skill.yaml
-- Source SHA-256: 878a322c6ecb8d008c5c1eb3a818f63e55dfb38cdd5a00236fef47da90c6bd0a

SELECT
  p.upid,
  p.pid,
  p.name AS process_name
FROM process p
WHERE p.name LIKE '%systemui%'
  OR p.name LIKE '%SystemUI%'
  OR p.name = 'com.android.systemui'
LIMIT 1
