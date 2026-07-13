-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/launcher_module.skill.yaml
-- Source SHA-256: 09423f22ca1cc723d498d6e9ecfbfb935d5cf177154c5eab813f3bf7d0bcef40
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT
  p.upid,
  p.pid,
  p.name AS process_name,
  CASE
    WHEN p.name LIKE '%launcher%' OR p.name LIKE '%Launcher%' THEN 'launcher'
    WHEN p.name LIKE '%home%' OR p.name LIKE '%Home%' THEN 'home'
    WHEN p.name LIKE '%trebuchet%' THEN 'aosp_launcher'
    WHEN p.name LIKE '%nexuslauncher%' THEN 'pixel_launcher'
    WHEN p.name LIKE '%lawnchair%' THEN 'lawnchair'
    ELSE 'unknown'
  END AS launcher_type
FROM process p
WHERE p.name LIKE '%launcher%'
  OR p.name LIKE '%Launcher%'
  OR p.name LIKE '%home%'
  OR p.name LIKE '%trebuchet%'
  OR p.name LIKE '%nexuslauncher%'
LIMIT 5
