-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 2608305b18a6513dfcc208dc9b7094457f4b581a131e6abecd7116b127802254
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

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
