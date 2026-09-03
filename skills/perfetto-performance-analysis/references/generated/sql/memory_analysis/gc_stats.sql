-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: cdf7ef77bd46ca7ff4ab49a48acc199332397fade61d1e9cbc71b3270f4f8bc4
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

SELECT
  CASE gc_type
    WHEN 'ConcurrentCopying' THEN 'ConcurrentCopying (并发GC)'
    WHEN 'MarkSweep' THEN 'MarkSweep (标记清除)'
    WHEN 'Explicit' THEN 'Explicit (显式GC)'
    WHEN 'Alloc' THEN 'Alloc (分配触发)'
    WHEN 'Background' THEN 'Background (后台GC)'
    WHEN 'Young' THEN 'Young Gen (新生代)'
    WHEN 'Full' THEN 'Full GC (全局)'
    ELSE 'Other'
  END as gc_type,
  COUNT(*) as count,
  SUM(dur) / 1e6 as total_dur_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_dur_ms,
  SUM(CASE WHEN is_main_thread = 1 THEN 1 ELSE 0 END) as main_thread_count
FROM _gc_events
GROUP BY gc_type
ORDER BY total_dur_ms DESC
