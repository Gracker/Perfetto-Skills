-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_frequency_limit_episode.skill.yaml
-- Source SHA-256: b02b4e752ee6809352b02fbf8267c6cd3900768a842fe46ba886cfc61a79bbbd
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

WITH
-- Quality gates apply per track, not per sensor name or individual value.
-- Null units are inferred conservatively and disclosed; explicit unknown units
-- are never overridden. Skin and junction temperatures are not interchangeable.
--
-- counter_track.type='thermal_temperature' is produced by the ftrace event
-- thermal/thermal_temperature, whose value is millidegrees Celsius by
-- definition. For those tracks the unit is therefore KNOWN (unit_basis
-- 'perfetto_track_type') and must not be guessed from the observed value
-- range: a device that only ever reports 30-40 C would otherwise be read as
-- degrees and silently reported 1000x too hot. Range inference stays in place
-- for untyped tracks that merely have a thermal-looking name.
thermal_tracks AS (
  SELECT id, name, unit, type FROM counter_track
  WHERE type = 'thermal_temperature'
    OR LOWER(name) LIKE '%thermal%' OR LOWER(name) LIKE '%temp%'
    OR LOWER(name) LIKE '%tsens%'
),
thermal_raw AS (
  SELECT c.id, c.ts, c.track_id AS sensor_track_id, ct.name AS sensor_name,
    ct.unit AS source_unit, ct.type AS track_type, c.value,
    MAX(ABS(c.value)) OVER (PARTITION BY ct.id) AS track_max_abs
  FROM thermal_tracks ct JOIN counter c ON c.track_id = ct.id
  WHERE (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
thermal_normalized AS (
  SELECT *, CASE
    WHEN source_unit IN ('C', '°C', 'celsius') THEN value
    WHEN source_unit IN ('mC', 'millidegrees', 'millidegree_celsius') THEN value / 1000.0
    WHEN source_unit IS NULL AND track_type = 'thermal_temperature' THEN value / 1000.0
    WHEN source_unit IS NULL AND track_max_abs > 1000 THEN value / 1000.0
    WHEN source_unit IS NULL THEN value
    ELSE NULL END AS temp_c,
    CASE WHEN source_unit IS NOT NULL THEN 'explicit_unit'
      WHEN track_type = 'thermal_temperature' THEN 'perfetto_track_type'
      ELSE 'inferred_from_track_range' END AS unit_basis
  FROM thermal_raw
),
thermal_ordered AS (
  SELECT *, LAG(temp_c) OVER (PARTITION BY sensor_track_id ORDER BY ts, id) AS prev_temp_c,
    LAG(ts) OVER (PARTITION BY sensor_track_id ORDER BY ts, id) AS prev_ts
  FROM thermal_normalized
),
thermal_track_stats AS (
  SELECT sensor_track_id, sensor_name, source_unit, unit_basis,
    COUNT(*) AS sample_count, MIN(ts) AS first_ts, MAX(ts) AS last_ts,
    MIN(temp_c) AS raw_min_temp_c, MAX(temp_c) AS raw_max_temp_c,
    AVG(temp_c) AS raw_avg_temp_c,
    CASE WHEN COUNT(*) < 5 THEN 'insufficient_samples'
      WHEN COUNT(temp_c) != COUNT(*) THEN 'unsupported_unit'
      WHEN MIN(temp_c) < 5 OR MAX(temp_c) > 150 THEN 'implausible_range'
      WHEN MAX(CASE WHEN prev_ts IS NOT NULL AND ts - prev_ts <= 100000000
        AND ABS(temp_c - prev_temp_c) > 10 THEN 1 ELSE 0 END) = 1 THEN 'abrupt_jump'
      ELSE 'accepted' END AS sample_quality
  FROM thermal_ordered
  GROUP BY sensor_track_id, sensor_name, source_unit, unit_basis
),
thermal_valid_samples AS (
  SELECT s.* FROM thermal_ordered s JOIN thermal_track_stats q USING(sensor_track_id)
  WHERE q.sample_quality = 'accepted'
)
,
win AS (
  SELECT ${episode_windows.data[0].before_start_ts} AS before_start_ts,
    ${episode_windows.data[0].before_end_ts} AS before_end_ts
),
-- When the trace carries typed thermal_temperature tracks, a track that
-- merely has a thermal-sounding NAME (an app called ThermalActivity, a
-- buffer counter) is noise, not a sensor. Name matching is only kept as
-- the fallback for traces with no typed thermal track at all.
typed_available AS (
  SELECT COUNT(*) AS n FROM thermal_raw WHERE track_type = 'thermal_temperature'
),
in_window AS (
  SELECT o.sensor_track_id, o.sensor_name, o.ts, o.temp_c, o.id, o.track_type,
    q.sample_quality, q.unit_basis
  FROM thermal_ordered o
  JOIN thermal_track_stats q USING (sensor_track_id)
  WHERE o.ts >= (SELECT before_start_ts FROM win)
    AND o.ts < (SELECT before_end_ts FROM win)
    AND (o.track_type = 'thermal_temperature' OR (SELECT n FROM typed_available) = 0)
)
SELECT sensor_name,
  COUNT(*) AS sample_count_in_window,
  CASE WHEN MAX(w.track_type) = 'thermal_temperature'
    THEN 'perfetto_thermal_temperature_track'
    ELSE 'name_matched_track_no_typed_thermal_track_in_trace' END AS track_basis,
  MAX(unit_basis) AS unit_basis,
  MAX(sample_quality) AS sample_quality,
  ROUND((SELECT w2.temp_c FROM in_window w2
    WHERE w2.sensor_track_id = w.sensor_track_id ORDER BY w2.ts, w2.id LIMIT 1), 1) AS first_temp_c,
  ROUND((SELECT w2.temp_c FROM in_window w2
    WHERE w2.sensor_track_id = w.sensor_track_id ORDER BY w2.ts DESC, w2.id DESC LIMIT 1), 1) AS last_temp_c,
  ROUND(MAX(w.temp_c), 1) AS max_temp_c,
  ROUND((SELECT w2.temp_c FROM in_window w2
    WHERE w2.sensor_track_id = w.sensor_track_id ORDER BY w2.ts DESC, w2.id DESC LIMIT 1)
    - (SELECT w2.temp_c FROM in_window w2
    WHERE w2.sensor_track_id = w.sensor_track_id ORDER BY w2.ts, w2.id LIMIT 1), 1) AS rise_c,
  MIN(w.ts) AS first_ts, MAX(w.ts) AS last_ts,
  CASE WHEN MAX(w.sample_quality) != 'accepted' THEN 'suspect_' || MAX(w.sample_quality)
    WHEN COUNT(*) < 2 THEN 'single_sample_no_trend'
    ELSE 'observed' END AS temperature_evidence,
  'observation_not_causal' AS evidence_scope
FROM in_window w
GROUP BY w.sensor_track_id, w.sensor_name
ORDER BY max_temp_c DESC
