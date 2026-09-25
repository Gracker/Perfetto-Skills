-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/ams_module.skill.yaml
-- Source SHA-256: b7456b08a71144dfea211e1e651da605e3683fe7e4512fb761c7ae45b55d2074
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  intent_action AS broadcast_action,
  CAST(dur / 1e6 AS REAL) AS dur_ms,
  ts
FROM _android_broadcasts_minsdk_u
WHERE ts >= (SELECT ts FROM android_startups WHERE ('${package}' = '' OR package = '${package}') ORDER BY ts DESC LIMIT 1)
  AND ts <= (SELECT ts + dur FROM android_startups WHERE ('${package}' = '' OR package = '${package}') ORDER BY ts DESC LIMIT 1)
ORDER BY dur DESC
LIMIT 10
