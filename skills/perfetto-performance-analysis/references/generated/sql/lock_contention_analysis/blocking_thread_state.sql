-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  thread_state,
  COUNT(*) AS count,
  ROUND(SUM(thread_state_dur) / 1e6, 2) AS total_dur_ms,
  ROUND(AVG(thread_state_dur) / 1e6, 2) AS avg_dur_ms
FROM android_monitor_contention_chain_thread_state_by_txn
GROUP BY thread_state
ORDER BY total_dur_ms DESC
