-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/compose_recomposition_hotspot.skill.yaml
-- Source SHA-256: 7f426a90804f6efc3d8ec7d94af37a4b4879abfa2ff4c95cf6360b70d16ca06a
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

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
WHERE (('${package}' = '' OR s.process_name = '${package}' OR s.process_name GLOB '${package}:*') OR '${package}' = '')
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND (s.name GLOB 'Recompos*' OR s.name GLOB 'Compose:*' OR s.name GLOB '*CompositionLocal*')
  AND s.dur > 8000000
ORDER BY s.dur DESC
LIMIT 50
