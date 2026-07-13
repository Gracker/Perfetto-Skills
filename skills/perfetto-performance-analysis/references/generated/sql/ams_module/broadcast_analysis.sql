-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/ams_module.skill.yaml
-- Source SHA-256: a39931677061435b7e6004f603fa590fc51196fd1619697154b7f89e5c1510ec
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  intent_action AS broadcast_action,
  CAST(dur / 1e6 AS REAL) AS dur_ms,
  ts
FROM _android_broadcasts_minsdk_u
WHERE ts >= (SELECT ts FROM android_startups WHERE package LIKE '%${package}%' ORDER BY ts DESC LIMIT 1)
  AND ts <= (SELECT ts + dur FROM android_startups WHERE package LIKE '%${package}%' ORDER BY ts DESC LIMIT 1)
ORDER BY dur DESC
LIMIT 10
