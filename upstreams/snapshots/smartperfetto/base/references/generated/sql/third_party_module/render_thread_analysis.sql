-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: dacb92b3b21e6a6eb465c54481840390078de91ffe280ccb2ee14d978360ae96
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  state,
  CAST(SUM(dur) / 1e6 AS INTEGER) AS dur_ms
FROM thread_state
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE thread.name = 'RenderThread'
  AND process.name LIKE '%${package}%'
GROUP BY state
ORDER BY dur_ms DESC
