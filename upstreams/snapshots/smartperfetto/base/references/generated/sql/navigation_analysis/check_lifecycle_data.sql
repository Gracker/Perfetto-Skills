-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/navigation_analysis.skill.yaml
-- Source SHA-256: 22cd4dfce1fd88d4610a41825267b0c17ab31811b871551db13a6719c8466f52

SELECT
  COUNT(*) as event_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
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
    OR s.name GLOB '*performPause*'
    OR s.name GLOB '*performStop*'
    OR s.name GLOB '*performDestroy*'
    OR s.name GLOB '*activityStart*'
    OR s.name GLOB '*activityResume*'
  )
