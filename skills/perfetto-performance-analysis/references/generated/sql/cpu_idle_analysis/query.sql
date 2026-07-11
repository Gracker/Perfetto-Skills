-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_idle_analysis.skill.yaml
-- Source SHA-256: 231e8ce685c178ba67e1e32c7f5fcdb25ba5b5b0b0773af5145ca0572d6b4861
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH all_idle_events AS (
  -- 不在时间窗口内过滤，避免 LEAD() 丢失跨边界的 idle 区间
  SELECT
    cct.cpu,
    c.ts,
    CAST(c.value AS INTEGER) as idle_state,
    LEAD(c.ts) OVER (PARTITION BY cct.cpu ORDER BY c.ts) as next_ts
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name = 'cpuidle'
    AND ('${cpu_ids|}'  = '' OR cct.cpu IN (${cpu_ids|}))
),
idle_durations AS (
  SELECT
    cpu,
    idle_state,
    -- 将 idle 区间裁剪到分析窗口内
    MIN(next_ts, COALESCE(${end_ts}, next_ts)) - MAX(ts, COALESCE(${start_ts}, ts)) as dur
  FROM all_idle_events
  WHERE idle_state >= 0
    AND next_ts IS NOT NULL
    -- 只要区间与分析窗口有交集
    AND (${start_ts} IS NULL OR next_ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
)
SELECT
  cpu,
  idle_state,
  COUNT(*) as entry_count,
  ROUND(SUM(dur) / 1e6, 1) as total_idle_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_idle_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_idle_ms
FROM idle_durations
GROUP BY cpu, idle_state
ORDER BY cpu, idle_state
