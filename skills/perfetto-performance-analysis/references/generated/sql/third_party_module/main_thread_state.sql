-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: 187161c0bb28c5b2c3fc7793981fd519e399d3a17ee5a07d05ea9d64daf388b5

SELECT
  state,
  CAST(SUM(dur) / 1e6 AS INTEGER) AS dur_ms,
  ROUND(SUM(dur) * 100.0 / (SELECT SUM(dur) FROM thread_state ts2 JOIN thread t2 USING (utid) JOIN process p2 USING (upid) WHERE t2.name = 'main' AND ('${package}' = '' OR p2.name = '${package}' OR p2.name GLOB '${package}:*')), 1) AS pct
FROM thread_state
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE thread.name = 'main'
  AND ('${package}' = '' OR process.name = '${package}' OR process.name GLOB '${package}:*')
GROUP BY state
ORDER BY dur_ms DESC
