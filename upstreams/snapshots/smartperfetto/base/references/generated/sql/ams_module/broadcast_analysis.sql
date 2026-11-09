-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/ams_module.skill.yaml
-- Source SHA-256: 3793610c048eb2cd2f719edc363d9f5cf72702f7b6b45fd0845449fba3423cd1

SELECT
  intent_action AS broadcast_action,
  CAST(dur / 1e6 AS REAL) AS dur_ms,
  ts
FROM _android_broadcasts_minsdk_u
WHERE ts >= (SELECT ts FROM android_startups WHERE ('${package}' = '' OR package = '${package}') ORDER BY ts DESC LIMIT 1)
  AND ts <= (SELECT ts + dur FROM android_startups WHERE ('${package}' = '' OR package = '${package}') ORDER BY ts DESC LIMIT 1)
ORDER BY dur DESC
LIMIT 10
