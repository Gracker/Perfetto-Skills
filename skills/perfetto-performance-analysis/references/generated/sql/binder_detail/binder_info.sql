-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_detail.skill.yaml
-- Source SHA-256: abd94ce08b891e6024eee4eb3ed9edc80baf296988105e6eebafe7e693921759
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  '${server_process}' as server_process,
  '${aidl_name}' as aidl_name,
  '${process_name}' as client_process,
  ROUND(${dur_ms}, 2) as dur_ms,
  printf('%d', ${binder_ts}) as binder_ts,
  printf('%d', ${binder_end_ts}) as binder_end_ts,
  -- Perfetto 跳转链接参数
  printf('%d', COALESCE(${perfetto_start}, ${binder_ts})) as perfetto_start,
  printf('%d', COALESCE(${perfetto_end}, ${binder_end_ts})) as perfetto_end,
  -- 评级
  CASE
    WHEN ${dur_ms} > 50 THEN '严重'
    WHEN ${dur_ms} > 16 THEN '需优化'
    ELSE '正常'
  END as rating
