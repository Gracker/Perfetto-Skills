-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: cdec84f3101148083ffa1b4e4d4fd0fd16bfcac16c0a71b257ca50f86c84311c
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  gc_name as gc_type,
  dur / 1e6 as dur_ms,
  ts / 1e6 as ts_ms,
  printf('%d', ts) as ts_str,
  printf('%d', dur) as dur_str,
  CASE
    WHEN dur / 1e6 > ${single_gc_warning_ms|50} THEN 'critical'
    WHEN dur / 1e6 > 16 THEN 'warning'
    WHEN dur / 1e6 > 8 THEN 'notice'
    ELSE 'normal'
  END as severity,
  -- 掉帧数估算（使用动态 VSync 周期）
  CAST(dur / ${vsync_info.data[0].vsync_period_ns|16666667} AS INTEGER) as dropped_frames
FROM _gc_events
WHERE is_main_thread = 1
  AND dur > 1000000  -- > 1ms
ORDER BY dur DESC
LIMIT 20
