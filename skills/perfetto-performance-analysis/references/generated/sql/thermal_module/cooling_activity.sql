-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/thermal_module.skill.yaml
-- Source SHA-256: 6125d0a80aa8a0085e13bd9dde675dcd250b22db719a7359f4c54c3503a4fd33
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

-- Match the typed cooling_device_counter track first. The previous
-- GLOB '*cooling*' filter is case sensitive and never matched the actual
-- Perfetto track name, which is '<cdev> Cooling Device'. Name globs are
-- kept as a lowercase fallback for traces without the typed track.
SELECT
  ct.name AS cooling_device,
  ct.type AS track_type,
  CASE WHEN ct.type = 'cooling_device_counter'
    THEN 'perfetto_cooling_device_counter_track'
    ELSE 'name_glob_fallback' END AS match_basis,
  CAST(MIN(c.value) AS INTEGER) AS min_level,
  CAST(MAX(c.value) AS INTEGER) AS max_level,
  CAST(AVG(c.value) AS INTEGER) AS avg_level,
  'arithmetic_sample_mean_not_time_weighted' AS aggregation_basis,
  COUNT(*) AS sample_count
FROM counter c
JOIN counter_track ct ON c.track_id = ct.id
WHERE (ct.type = 'cooling_device_counter'
  OR LOWER(ct.name) GLOB '*cooling*'
  OR LOWER(ct.name) GLOB '*fan*'
  OR LOWER(ct.name) GLOB '*cdev*')
  AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR c.ts < ${end_ts})
GROUP BY ct.id, ct.name, ct.type
ORDER BY avg_level DESC
