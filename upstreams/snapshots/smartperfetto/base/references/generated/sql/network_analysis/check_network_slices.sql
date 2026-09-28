-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 42f8702c1c1ee5326dedc0ff19beacffefd3055ddb59008ef90b81049c3c5d1e
-- Source commit: 42ef4dd2878646bf238a54d53c934d4d4f3e4b3f

SELECT
  COUNT(*) as slice_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM slice
WHERE (
    name GLOB '*network*'
    OR name GLOB '*Network*'
    OR name GLOB '*socket*'
    OR name GLOB '*Socket*'
    OR name GLOB '*DNS*'
    OR name GLOB '*dns*'
    OR name GLOB '*http*'
    OR name GLOB '*Http*'
    OR name GLOB '*connect*'
    OR name GLOB '*Connect*'
  )
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
