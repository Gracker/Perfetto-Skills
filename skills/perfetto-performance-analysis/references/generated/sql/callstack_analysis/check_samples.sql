-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: fc08d54c591a45a1488f7d1064504f08f7d3d2fa95b42eec2a1c6da725ec5f08
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  COUNT(*) as total_samples,
  COUNT(DISTINCT callsite_id) as unique_callsites,
  MIN(ts) as first_sample_ts,
  MAX(ts) as last_sample_ts,
  (MAX(ts) - MIN(ts)) / 1e9 as duration_sec
FROM perf_sample
HAVING COUNT(*) > 0
