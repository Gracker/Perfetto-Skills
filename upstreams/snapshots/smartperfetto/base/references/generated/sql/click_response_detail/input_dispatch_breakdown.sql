-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_detail.skill.yaml
-- Source SHA-256: 3bf411e6c0f6db9de2434fb0ad420cb0a0140388c5968306f5ad569b3ff0c3e7
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

-- 分解 Input dispatch 管线: kernel → InputDispatcher (system_server) → App
WITH dispatch_slices AS (
  -- InputDispatcher 处理阶段 (system_server 进程)
  SELECT
    'InputDispatcher' as stage,
    s.ts as start_ts,
    s.dur,
    t.name as thread_name,
    s.name as detail
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = 'system_server' OR p.name LIKE '/system/bin/%')
    AND (s.name GLOB '*InputDispatcher*' OR s.name GLOB '*InputReader*' OR s.name GLOB '*dispatchMotion*')
    AND s.ts >= (${event_ts} - 50000000)
    AND s.ts <= (${event_ts} + 50000000)
  UNION ALL
  -- App 端接收阶段 (aq:pending:deliver)
  SELECT
    'App接收' as stage,
    s.ts as start_ts,
    s.dur,
    t.name as thread_name,
    s.name as detail
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${process_name}*'
    AND (s.name GLOB '*deliverInput*' OR s.name GLOB 'aq:pending:deliver*' OR s.name GLOB '*InputEvent*')
    AND s.ts >= (${event_ts} - 10000000)
    AND s.ts <= (${event_end_ts} + 10000000)
)
SELECT
  stage,
  printf('%d', start_ts) as start_ts,
  ROUND(dur / 1e6, 2) as dur_ms,
  thread_name,
  detail
FROM dispatch_slices
ORDER BY start_ts
LIMIT 20
