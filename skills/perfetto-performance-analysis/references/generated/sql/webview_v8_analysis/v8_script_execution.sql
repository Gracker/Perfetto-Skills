-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/webview_v8_analysis.skill.yaml
-- Source SHA-256: 21b4aad17749f3d884e964c264f1cafceef566b01f105da76394c1ae7f0b20ca
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  printf('%d', s.ts) as ts,
  s.name as slice_name,
  p.name as process_name,
  t.name as thread_name,
  ROUND(s.dur / 1e6, 2) as dur_ms,
  printf('%d', s.dur) as dur_ns,
  CASE
    WHEN s.dur / 1e6 > 100 THEN 'critical'
    WHEN s.dur / 1e6 > 32 THEN 'warning'
    WHEN s.dur / 1e6 > 16 THEN 'notice'
    ELSE 'normal'
  END as severity
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND s.name GLOB '*v8.run*'
ORDER BY s.dur DESC
LIMIT 50
