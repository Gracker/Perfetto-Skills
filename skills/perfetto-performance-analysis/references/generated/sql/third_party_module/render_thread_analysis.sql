-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: 4ec1adf4fca9bc5c1c99e0f926c86d6b2effc9f0f47b5f20451dda2bc4807ad5
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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
