-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 6cc30df6302970712dcfa515969800f74b30e65154d9f53f2cfcb10587191188
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  blocked_function,
  ROUND(SUM(blocked_function_dur) / 1e6, 2) AS total_dur_ms,
  COUNT(*) AS count,
  ROUND(AVG(blocked_function_dur) / 1e6, 2) AS avg_dur_ms
FROM android_monitor_contention_chain_blocked_functions_by_txn
WHERE blocked_function IS NOT NULL
GROUP BY blocked_function
ORDER BY total_dur_ms DESC
LIMIT 20
