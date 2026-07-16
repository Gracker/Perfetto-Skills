-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/startup_detail.skill.yaml
-- Source SHA-256: 27c99e2bb5d9588e4ca6909bfd0a637f393af0211b692cc814005a00e99154c6
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

SELECT
  ${startup_id} as startup_id,
  '${package}' as package,
  '${startup_type}' as startup_type,
  CASE '${startup_type}'
    WHEN 'cold' THEN '冷启动'
    WHEN 'warm' THEN '温启动'
    WHEN 'hot' THEN '热启动'
    ELSE '${startup_type}'
  END as type_display,
  ROUND(${dur_ms}, 2) as dur_ms,
  ROUND(${ttid_ms}, 2) as ttid_ms,
  ROUND(${ttfd_ms}, 2) as ttfd_ms,
  -- 时间戳
  printf('%d', ${start_ts}) as start_ts,
  printf('%d', ${end_ts}) as end_ts,
  -- Perfetto 跳转链接参数
  printf('%d', COALESCE(${perfetto_start}, ${start_ts})) as perfetto_start,
  printf('%d', COALESCE(${perfetto_end}, ${end_ts})) as perfetto_end,
  -- 评级
  CASE
    WHEN '${startup_type}' = 'cold' AND ${dur_ms} < 500 THEN '优秀'
    WHEN '${startup_type}' = 'cold' AND ${dur_ms} < 1000 THEN '良好'
    WHEN '${startup_type}' = 'cold' AND ${dur_ms} < 2000 THEN '需优化'
    WHEN '${startup_type}' = 'cold' THEN '严重'
    WHEN '${startup_type}' = 'warm' AND ${dur_ms} < 200 THEN '优秀'
    WHEN '${startup_type}' = 'warm' AND ${dur_ms} < 500 THEN '良好'
    WHEN '${startup_type}' = 'warm' AND ${dur_ms} < 1000 THEN '需优化'
    WHEN '${startup_type}' = 'warm' THEN '严重'
    WHEN '${startup_type}' = 'hot' AND ${dur_ms} < 100 THEN '优秀'
    WHEN '${startup_type}' = 'hot' AND ${dur_ms} < 200 THEN '良好'
    WHEN '${startup_type}' = 'hot' AND ${dur_ms} < 500 THEN '需优化'
    WHEN '${startup_type}' = 'hot' THEN '严重'
    ELSE '需优化'
  END as rating
