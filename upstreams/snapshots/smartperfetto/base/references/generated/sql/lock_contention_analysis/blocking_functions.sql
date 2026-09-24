-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

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
