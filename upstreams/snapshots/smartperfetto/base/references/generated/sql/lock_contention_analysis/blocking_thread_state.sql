-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 6cc30df6302970712dcfa515969800f74b30e65154d9f53f2cfcb10587191188
-- Source commit: 42ef4dd2878646bf238a54d53c934d4d4f3e4b3f

SELECT
  thread_state,
  COUNT(*) AS count,
  ROUND(SUM(thread_state_dur) / 1e6, 2) AS total_dur_ms,
  ROUND(AVG(thread_state_dur) / 1e6, 2) AS avg_dur_ms
FROM android_monitor_contention_chain_thread_state_by_txn
GROUP BY thread_state
ORDER BY total_dur_ms DESC
