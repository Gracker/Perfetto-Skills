-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: b0d6f1c51fe5e8687db9cc5ec9b1df231029151ee389c92bfb42f096e1ac13e0

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
