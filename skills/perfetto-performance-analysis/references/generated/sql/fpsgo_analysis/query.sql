-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/fpsgo_analysis.skill.yaml
-- Source SHA-256: 6ee6815848f62092599d709a15c857835fb298f96733192f8fc113c03acb42c3
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  CASE
    WHEN s.name GLOB '*fstb*' OR s.name GLOB '*FSTB*' THEN 'FSTB (帧稳定)'
    WHEN s.name GLOB '*fbt*' OR s.name GLOB '*FBT*' THEN 'FBT (急拉)'
    WHEN s.name GLOB '*boost*' OR s.name GLOB '*rescue*' THEN 'Boost/Rescue'
    WHEN s.name GLOB '*fpsgo*' THEN 'FPSGO (其他)'
    WHEN s.name GLOB '*ged*' OR s.name GLOB '*GED*' THEN 'GED (GPU调度)'
    WHEN s.name GLOB '*perf_idx*' OR s.name GLOB '*PerfService*' OR s.name GLOB '*PowerHal*' THEN 'PerfService/PowerHal'
    ELSE 'Other Vendor'
  END as category,
  s.name as event_name,
  COUNT(*) as count,
  ROUND(SUM(s.dur) / 1e6, 1) as total_ms
FROM slice s
WHERE (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  AND (
    s.name GLOB '*fpsgo*' OR s.name GLOB '*FSTB*' OR s.name GLOB '*fbt*'
    OR s.name GLOB '*fstb*' OR s.name GLOB '*boost*' OR s.name GLOB '*rescue*'
    OR s.name GLOB '*ged*' OR s.name GLOB '*GED*'
    OR s.name GLOB '*perf_idx*' OR s.name GLOB '*PerfService*'
    OR s.name GLOB '*PowerHal*' OR s.name GLOB '*sched_boost*'
  )
GROUP BY category, s.name
HAVING count >= 1
ORDER BY category, count DESC
