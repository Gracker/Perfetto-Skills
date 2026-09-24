-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 2218440cfc32dab82a764464dea62719d04148dbaff34657cbe3590d4a063523
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

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
