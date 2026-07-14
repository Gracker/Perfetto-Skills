-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_detail.skill.yaml
-- Source SHA-256: 3bf411e6c0f6db9de2434fb0ad420cb0a0140388c5968306f5ad569b3ff0c3e7
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

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
