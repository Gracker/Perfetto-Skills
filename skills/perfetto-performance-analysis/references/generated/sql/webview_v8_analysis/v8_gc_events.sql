-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/webview_v8_analysis.skill.yaml
-- Source SHA-256: 2049705d85775c01fb32fc6391b66c22d69cd8ec313a1543111b4c0fbb42ad9f
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  CASE
    WHEN s.name GLOB '*MajorGC*' OR s.name GLOB '*V8.GCCompactor*' THEN 'MajorGC'
    WHEN s.name GLOB '*MinorGC*' OR s.name GLOB '*V8.GCScavenger*' THEN 'MinorGC'
    WHEN s.name GLOB '*v8.gc*' OR s.name GLOB '*V8.GC*' THEN 'V8.GC'
    ELSE 'Other GC'
  END as gc_type,
  p.name as process_name,
  COUNT(*) as count,
  ROUND(SUM(s.dur) / 1e6, 2) as total_dur_ms,
  ROUND(AVG(s.dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(s.dur) / 1e6, 2) as max_dur_ms,
  CASE
    WHEN MAX(s.dur) / 1e6 > 50 THEN '严重'
    WHEN MAX(s.dur) / 1e6 > 16 THEN '需优化'
    WHEN SUM(s.dur) / 1e6 > 100 THEN '需优化'
    ELSE '正常'
  END as rating
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (p.name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND (s.name GLOB '*v8.gc*' OR s.name GLOB '*V8.GC*'
       OR s.name GLOB '*MajorGC*' OR s.name GLOB '*MinorGC*'
       OR s.name GLOB '*V8.GCScavenger*' OR s.name GLOB '*V8.GCCompactor*')
GROUP BY gc_type, p.name
ORDER BY SUM(s.dur) DESC
