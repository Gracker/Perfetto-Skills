-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: da6f8f053e7325fffa6983751eaebd17478c4ae924e86352ffd66e4101d98660
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  COUNT(*) as total_samples,
  COUNT(DISTINCT callsite_id) as unique_callsites,
  MIN(ts) as first_sample_ts,
  MAX(ts) as last_sample_ts,
  (MAX(ts) - MIN(ts)) / 1e9 as duration_sec
FROM perf_sample
