-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/navigation_analysis.skill.yaml
-- Source SHA-256: b9e2d3fb86601d2c0f82d87e454f701201afac230ce76013877fe2252698fdb9
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  p.name as process_name,
  COUNT(*) as event_count
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE t.tid = p.pid
  AND (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
  AND (${start_ts} IS NULL OR s.ts + s.dur > ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  AND (
    s.name GLOB '*performCreate*'
    OR s.name GLOB '*performStart*'
    OR s.name GLOB '*performResume*'
    OR s.name GLOB '*activityStart*'
    OR s.name GLOB '*activityResume*'
  )
GROUP BY p.name
ORDER BY event_count DESC
LIMIT 1
