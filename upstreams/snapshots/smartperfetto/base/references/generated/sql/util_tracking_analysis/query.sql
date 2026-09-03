-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/util_tracking_analysis.skill.yaml
-- Source SHA-256: f43141f7af054b22d9f434f439e6b550daf56200f0ea5b3ba014c7055dd975b0
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

-- 分析启动/滑动前 100ms 的频率 vs 实际负载，检测 util 建模延迟
-- 如果任务一直在 Running 但频率低，说明 util_avg 还没反映真实负载
WITH task_running AS (
  SELECT ss.ts, ss.dur, ss.cpu
  FROM sched_slice ss
  JOIN thread t ON ss.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE t.is_main_thread = 1
    AND ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND ss.ts BETWEEN ${start_ts} AND CAST(${start_ts} AS INTEGER) + 100000000
),
freq_at_time AS (
  SELECT c.ts, CAST(c.value AS INTEGER) as freq, cct.cpu
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name GLOB 'cpu*freq*'
    AND c.ts BETWEEN ${start_ts} AND CAST(${start_ts} AS INTEGER) + 100000000
)
SELECT
  ROUND((tr.ts - ${start_ts}) / 1e6, 1) as offset_ms,
  tr.cpu,
  ROUND(tr.dur / 1e6, 2) as running_ms,
  COALESCE(
    (SELECT f.freq / 1000 FROM freq_at_time f
     WHERE f.cpu = tr.cpu AND f.ts <= tr.ts
     ORDER BY f.ts DESC LIMIT 1),
    0
  ) as freq_mhz
FROM task_running tr
ORDER BY tr.ts
LIMIT 30
