-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: da6f8f053e7325fffa6983751eaebd17478c4ae924e86352ffd66e4101d98660
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  COUNT(*) as total_samples,
  COUNT(DISTINCT callsite_id) as unique_callsites,
  MIN(ts) as first_sample_ts,
  MAX(ts) as last_sample_ts,
  (MAX(ts) - MIN(ts)) / 1e9 as duration_sec
FROM perf_sample
