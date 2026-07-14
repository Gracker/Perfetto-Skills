-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/systemui_module.skill.yaml
-- Source SHA-256: 8fefc68721ff7d5c29a0efbcda086e11d9c62e892c17a37f39604b26b1729566
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  p.upid,
  p.pid,
  p.name AS process_name
FROM process p
WHERE p.name LIKE '%systemui%'
  OR p.name LIKE '%SystemUI%'
  OR p.name = 'com.android.systemui'
LIMIT 1
