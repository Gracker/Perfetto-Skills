-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: d005054dab0e8c6ea08c377ca3407e935fb7134f30aa318211845cf32f3e2a0a
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

SELECT
  bt.server_process,
  bt.aidl_name,
  bt.client_dur / 1e6 as binder_dur_ms,
  -- JOIN thread_state 分析阻塞期间的状态
  ts.state,
  ts.blocked_function,
  SUM(ts.dur) / 1e6 as state_dur_ms,
  ROUND(100.0 * SUM(ts.dur) / bt.client_dur, 1) as state_percent,
  printf('%d', bt.client_ts) as ts_str
FROM android_binder_txns bt
JOIN thread_state ts ON (
  ts.utid = bt.client_utid
  AND ts.ts >= bt.client_ts
  AND ts.ts < bt.client_ts + bt.client_dur
)
WHERE bt.client_process = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
  AND bt.is_main_thread = 1
  AND bt.client_dur > 5000000  -- > 5ms
GROUP BY bt.client_ts, bt.client_utid, bt.server_process, bt.aidl_name, bt.client_dur, ts.state
ORDER BY bt.client_dur DESC, state_dur_ms DESC
LIMIT 30
