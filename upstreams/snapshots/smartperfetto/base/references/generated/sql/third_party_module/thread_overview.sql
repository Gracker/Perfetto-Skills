-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: dacb92b3b21e6a6eb465c54481840390078de91ffe280ccb2ee14d978360ae96
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

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
