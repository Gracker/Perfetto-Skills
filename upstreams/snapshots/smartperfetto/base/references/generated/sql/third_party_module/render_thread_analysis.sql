-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: 2171f2d0270a73b925955d869ff6f79c58b686da28d2da8e6785423c1aa1aedb
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  state,
  CAST(SUM(dur) / 1e6 AS INTEGER) AS dur_ms
FROM thread_state
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE thread.name = 'RenderThread'
  AND ('${package}' = '' OR process.name = '${package}' OR process.name GLOB '${package}:*')
GROUP BY state
ORDER BY dur_ms DESC
