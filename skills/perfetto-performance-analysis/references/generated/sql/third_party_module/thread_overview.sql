-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/third_party_module.skill.yaml
-- Source SHA-256: 2171f2d0270a73b925955d869ff6f79c58b686da28d2da8e6785423c1aa1aedb
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
