-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: cdf7ef77bd46ca7ff4ab49a48acc199332397fade61d1e9cbc71b3270f4f8bc4
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

SELECT
  gc.gc_name,
  gc.dur / 1e6 as gc_dur_ms,
  af.jank_type,
  af.dur / 1e6 as frame_dur_ms,
  CASE
    WHEN af.jank_type != 'None' THEN 'GC导致掉帧'
    WHEN af.dur > ${vsync_info.data[0].vsync_period_ns|16666667} THEN '帧超时'
    ELSE '正常'
  END as impact
FROM _gc_events gc
LEFT JOIN actual_frame_timeline_slice af ON (
  gc.ts >= af.ts AND gc.ts < af.ts + af.dur
)
LEFT JOIN process p ON af.upid = p.upid
WHERE gc.is_main_thread = 1
  AND ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
ORDER BY gc.dur DESC
LIMIT 30
