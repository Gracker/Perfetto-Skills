-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_detail.skill.yaml
-- Source SHA-256: 051bdc9c5edc28e6120e77e34dfa9036ffbfc5b1c4ea529604ca31a7435714b5
-- Source commit: eec8bff767eb3277f1f0dd106d0d7a0cfdab2dfc

SELECT
  '${event_type}' as event_type,
  '${event_action}' as event_action,
  '${process_name}' as process_name,
  ROUND(${total_ms}, 2) as total_ms,
  ROUND(COALESCE(${dispatch_ms}, 0), 2) as dispatch_ms,
  ROUND(COALESCE(${handling_ms}, 0), 2) as handling_ms,
  printf('%d', ${event_ts}) as event_ts,
  printf('%d', ${event_end_ts}) as event_end_ts,
  -- Perfetto 跳转链接参数
  printf('%d', COALESCE(${perfetto_start}, ${event_ts})) as perfetto_start,
  printf('%d', COALESCE(${perfetto_end}, ${event_end_ts})) as perfetto_end,
  -- 延迟主要来源
  CASE
    WHEN COALESCE(${dispatch_ms}, 0) > COALESCE(${handling_ms}, 0) THEN '系统分发'
    ELSE '应用处理'
  END as main_bottleneck,
  -- 评级
  CASE
    WHEN ${total_ms} > 200 THEN '严重'
    WHEN ${total_ms} > 100 THEN '较慢'
    ELSE '偏慢'
  END as rating
