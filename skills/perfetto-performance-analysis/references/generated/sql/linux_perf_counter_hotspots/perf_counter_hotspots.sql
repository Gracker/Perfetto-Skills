-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/linux_perf_counter_hotspots.skill.yaml
-- Source SHA-256: af7bb5a650cb5630f9a7660853cbc71766190fc42683c59a3cbdd8625d24f3aa
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
WHERE (i.target_process = '' OR p.name = i.target_process OR p.name GLOB i.target_process || ':*')
  AND l.ts >= i.start_ts
  AND l.ts < i.end_ts
GROUP BY counter_name, process_name, thread_name
ORDER BY total_counter_value DESC, sample_count DESC
LIMIT 100
