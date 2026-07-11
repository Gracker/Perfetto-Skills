-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: 4ec1adf4fca9bc5c1c99e0f926c86d6b2effc9f0f47b5f20451dda2bc4807ad5
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  state,
  CAST(SUM(dur) / 1e6 AS INTEGER) AS dur_ms,
  ROUND(SUM(dur) * 100.0 / (SELECT SUM(dur) FROM thread_state ts2 JOIN thread t2 USING (utid) JOIN process p2 USING (upid) WHERE t2.name = 'main' AND p2.name LIKE '%${package}%'), 1) AS pct
FROM thread_state
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE thread.name = 'main'
  AND process.name LIKE '%${package}%'
GROUP BY state
ORDER BY dur_ms DESC
