-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: c2723137b1cdfaa2c0f8b23cc62a9133aa534e56dc981c472ddc8d28ca6dff14
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH
cpu_by_process AS (
  SELECT
    p.upid as upid,
    SUM(ss.dur) as cpu_dur
  FROM sched_slice ss
  JOIN thread t ON ss.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (${start_ts} IS NULL OR ss.ts + ss.dur > ${start_ts})
    AND (${end_ts} IS NULL OR ss.ts < ${end_ts})
  GROUP BY p.upid
),
candidates AS (
  SELECT
    p.upid,
    p.pid,
    p.name as process_name,
    COALESCE(cb.cpu_dur, 0) as cpu_dur
  FROM process p
  LEFT JOIN cpu_by_process cb USING (upid)
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    -- 避免 package 为空时选到内核线程 (kworker 等)
    AND p.name NOT GLOB 'kworker*'
    AND p.name NOT GLOB 'swapper*'
    AND p.name NOT GLOB 'rcu*'
    AND p.name NOT GLOB 'irq*'
    AND p.name NOT GLOB 'migration*'
    AND p.name NOT GLOB 'ksoftirqd*'
)
SELECT
  upid,
  pid,
  process_name
FROM candidates
ORDER BY
  CASE WHEN '${package}' != '' AND process_name GLOB '${package}*' THEN 0 ELSE 1 END,
  -- package 为空时优先选择 app 进程（通常包含 '.'）
  CASE WHEN '${package}' = '' AND process_name LIKE '%.%' THEN 0 ELSE 1 END,
  cpu_dur DESC,
  pid DESC
LIMIT 1
