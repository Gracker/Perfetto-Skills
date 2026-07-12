-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/compose_recomposition_hotspot.skill.yaml
-- Source SHA-256: 2895ae93d263a1097b752875bc22c0e4521e6f96b6ad4feb319da03a76a0d59b
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  printf('%d', s.ts) as ts,
  s.name as slice_name,
  s.process_name,
  s.thread_name,
  ROUND(s.dur / 1e6, 2) as dur_ms,
  printf('%d', s.dur) as dur_ns,
  CASE
    WHEN s.dur / 1e6 > 32 THEN 'critical'
    WHEN s.dur / 1e6 > 16 THEN 'warning'
    ELSE 'notice'
  END as severity
FROM thread_slice s
WHERE (s.process_name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND (s.name GLOB 'Recompos*' OR s.name GLOB 'Compose:*' OR s.name GLOB '*CompositionLocal*')
  AND s.dur > 8000000
ORDER BY s.dur DESC
LIMIT 50
