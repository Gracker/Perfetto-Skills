-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/ams_module.skill.yaml
-- Source SHA-256: bfd2cd1f208acc814f9da8ed0ec0b02c0d5fd7226da25bec898e8de516e315cd

SELECT
  intent_action AS broadcast_action,
  CAST(dur / 1e6 AS REAL) AS dur_ms,
  ts
FROM _android_broadcasts_minsdk_u
WHERE ts >= (SELECT ts FROM android_startups WHERE ('${package}' = '' OR package = '${package}') ORDER BY ts DESC LIMIT 1)
  AND ts <= (SELECT ts + dur FROM android_startups WHERE ('${package}' = '' OR package = '${package}') ORDER BY ts DESC LIMIT 1)
ORDER BY dur DESC
LIMIT 10
