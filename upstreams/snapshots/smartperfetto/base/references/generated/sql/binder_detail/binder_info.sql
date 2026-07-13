-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_detail.skill.yaml
-- Source SHA-256: b21af48bb190aa382256c422c77267cce8f041f42257cbbd3a6f669e691f5bf9
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

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
