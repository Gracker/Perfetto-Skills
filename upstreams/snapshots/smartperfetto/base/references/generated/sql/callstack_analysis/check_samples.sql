-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: 32723ee660e8cc822dc7b98136a23b15ba55fc88f77942c0ee0b658a654680f1
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  COUNT(*) as total_samples,
  COUNT(DISTINCT callsite_id) as unique_callsites,
  MIN(ts) as first_sample_ts,
  MAX(ts) as last_sample_ts,
  (MAX(ts) - MIN(ts)) / 1e9 as duration_sec
FROM perf_sample
HAVING COUNT(*) > 0
