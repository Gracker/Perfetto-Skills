-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/compose_recomposition_hotspot.skill.yaml
-- Source SHA-256: 2895ae93d263a1097b752875bc22c0e4521e6f96b6ad4feb319da03a76a0d59b
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

SELECT
  s.name as slice_name,
  s.process_name as process_name,
  COUNT(*) as count,
  ROUND(SUM(s.dur) / 1e6, 2) as total_dur_ms,
  ROUND(AVG(s.dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(s.dur) / 1e6, 2) as max_dur_ms,
  CASE
    WHEN SUM(s.dur) / 1e6 > 100 THEN '严重'
    WHEN SUM(s.dur) / 1e6 > 50 THEN '需优化'
    WHEN COUNT(*) > 100 THEN '需优化'
    ELSE '正常'
  END as rating
FROM thread_slice s
WHERE (s.process_name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND (s.name GLOB 'Recompos*' OR s.name GLOB 'Compose:*' OR s.name GLOB '*CompositionLocal*')
GROUP BY s.name, s.process_name
ORDER BY SUM(s.dur) DESC
