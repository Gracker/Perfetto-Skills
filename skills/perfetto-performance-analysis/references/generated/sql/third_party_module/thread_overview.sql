-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: 187161c0bb28c5b2c3fc7793981fd519e399d3a17ee5a07d05ea9d64daf388b5

SELECT
  thread.name AS thread_name,
  thread.tid,
  CAST(SUM(sched_slice.dur) / 1e6 AS INTEGER) AS cpu_time_ms,
  COUNT(*) AS slice_count
FROM sched_slice
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE ('${package}' = '' OR process.name = '${package}' OR process.name GLOB '${package}:*')
GROUP BY thread.utid
HAVING cpu_time_ms > 1
ORDER BY cpu_time_ms DESC
LIMIT 20
