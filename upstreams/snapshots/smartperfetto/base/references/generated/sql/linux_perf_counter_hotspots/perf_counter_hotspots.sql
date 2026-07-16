-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/linux_perf_counter_hotspots.skill.yaml
-- Source SHA-256: a45de9aedc3fc4f3cf6cf9056e2e50d0de44ab20831abdaa17a1351352564370
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts), 0) FROM linux_perf_sample_with_counters)) AS end_ts
)
SELECT
  COALESCE(tr.name, printf('counter:%d', l.track_id)) AS counter_name,
  COALESCE(p.name, '<kernel/unknown>') AS process_name,
  COALESCE(t.name, printf('utid:%d', l.utid)) AS thread_name,
  COUNT(*) AS sample_count,
  ROUND(SUM(l.counter_value), 2) AS total_counter_value,
  ROUND(AVG(l.counter_value), 2) AS avg_counter_value
FROM linux_perf_sample_with_counters l
LEFT JOIN thread t ON l.utid = t.utid
LEFT JOIN process p ON t.upid = p.upid
LEFT JOIN track tr ON l.track_id = tr.id
CROSS JOIN input i
WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
  AND l.ts >= i.start_ts
  AND l.ts < i.end_ts
GROUP BY counter_name, process_name, thread_name
ORDER BY total_counter_value DESC, sample_count DESC
LIMIT 100
