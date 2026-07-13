-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: dacb92b3b21e6a6eb465c54481840390078de91ffe280ccb2ee14d978360ae96
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

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
