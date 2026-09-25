-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 2218440cfc32dab82a764464dea62719d04148dbaff34657cbe3590d4a063523
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

SELECT
  thread_state,
  COUNT(*) AS count,
  ROUND(SUM(thread_state_dur) / 1e6, 2) AS total_dur_ms,
  ROUND(AVG(thread_state_dur) / 1e6, 2) AS avg_dur_ms
FROM android_monitor_contention_chain_thread_state_by_txn
GROUP BY thread_state
ORDER BY total_dur_ms DESC
