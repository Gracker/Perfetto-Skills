-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: 4ec1adf4fca9bc5c1c99e0f926c86d6b2effc9f0f47b5f20451dda2bc4807ad5
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  thread.name AS thread_name,
  thread.tid,
  CAST(SUM(sched_slice.dur) / 1e6 AS INTEGER) AS cpu_time_ms,
  COUNT(*) AS slice_count
FROM sched_slice
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE process.name LIKE '%${package}%'
GROUP BY thread.utid
HAVING cpu_time_ms > 1
ORDER BY cpu_time_ms DESC
LIMIT 20
