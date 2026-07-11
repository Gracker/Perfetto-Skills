-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/page_fault_in_range.skill.yaml
-- Source SHA-256: 70c0fb8c89dddfe8a92611deb19c60d9126c1ed8c1e5c43e8d5639ce5f451a37
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH target_threads AS (
  SELECT t.utid, t.name as thread_name
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND (t.tid = p.pid OR t.name = 'RenderThread' OR t.name LIKE '%Binder%')
),
memory_events AS (
  SELECT
    tt.thread_name,
    ts.dur,
    ts.blocked_function,
    CASE
      WHEN ts.blocked_function LIKE '%do_page_fault%' THEN 'page_fault'
      WHEN ts.blocked_function LIKE '%handle_mm_fault%' THEN 'page_fault'
      WHEN ts.blocked_function LIKE '%pf_%' THEN 'page_fault'
      WHEN ts.blocked_function LIKE '%__alloc_pages%' THEN 'alloc_pages'
      WHEN ts.blocked_function LIKE '%direct_reclaim%' THEN 'direct_reclaim'
      WHEN ts.blocked_function LIKE '%shrink_%' THEN 'memory_shrink'
      WHEN ts.blocked_function LIKE '%kswapd%' THEN 'kswapd'
      WHEN ts.blocked_function LIKE '%compaction%' THEN 'compaction'
      WHEN ts.blocked_function LIKE '%swap%' THEN 'swap'
      ELSE 'other_memory'
    END as fault_type
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  WHERE (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
    AND ts.state IN ('D', 'DK')
    AND ts.blocked_function IS NOT NULL
    AND (ts.blocked_function LIKE '%page%'
         OR ts.blocked_function LIKE '%pf_%'
         OR ts.blocked_function LIKE '%alloc%'
         OR ts.blocked_function LIKE '%reclaim%'
         OR ts.blocked_function LIKE '%kswapd%'
         OR ts.blocked_function LIKE '%shrink%'
         OR ts.blocked_function LIKE '%compaction%'
         OR ts.blocked_function LIKE '%swap%')
)
SELECT
  thread_name,
  fault_type,
  COUNT(*) as count,
  ROUND(SUM(dur) / 1e6, 2) as total_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_ms
FROM memory_events
WHERE fault_type != 'other_memory'
GROUP BY thread_name, fault_type
HAVING total_ms > 0.1
ORDER BY total_ms DESC
