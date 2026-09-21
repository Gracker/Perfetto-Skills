-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: d4e9863b2759a03fe335ca68987e3e400bc1aa0a503a3b2f711fc6173cae70a6
-- Source commit: bc007586871a720aed82537913617c64fb95a459

WITH
-- Quality gates apply per track, not per sensor name or individual value.
-- Null units are inferred conservatively and disclosed; explicit unknown units
-- are never overridden. Skin and junction temperatures are not interchangeable.
thermal_raw AS (
  SELECT c.id, c.ts, c.track_id AS sensor_track_id, ct.name AS sensor_name,
    ct.unit AS source_unit, c.value,
    MAX(ABS(c.value)) OVER (PARTITION BY ct.id) AS track_max_abs
  FROM counter c JOIN counter_track ct ON c.track_id = ct.id
  WHERE (LOWER(ct.name) LIKE '%thermal%' OR LOWER(ct.name) LIKE '%temp%'
    OR LOWER(ct.name) LIKE '%tsens%')
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
thermal_normalized AS (
  SELECT *, CASE
    WHEN source_unit IN ('C', '°C', 'celsius') THEN value
    WHEN source_unit IN ('mC', 'millidegrees', 'millidegree_celsius') THEN value / 1000.0
    WHEN source_unit IS NULL AND track_max_abs > 1000 THEN value / 1000.0
    WHEN source_unit IS NULL THEN value
    ELSE NULL END AS temp_c,
    CASE WHEN source_unit IS NULL THEN 'inferred_from_track_range'
      ELSE 'explicit_unit' END AS unit_basis
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
classified AS (
  SELECT *, SUM(CASE WHEN temp_c <= 60 OR prev_ts IS NULL OR ts - prev_ts > 5000000000
    THEN 1 ELSE 0 END) OVER (PARTITION BY sensor_track_id ORDER BY ts, id) AS period_id
  FROM thermal_valid_samples
)
SELECT sensor_track_id, sensor_name, printf('%d', MIN(ts)) AS start_ts,
  printf('%d', MAX(ts)) AS end_ts, ROUND((MAX(ts)-MIN(ts))/1e9, 2) AS duration_sec,
  ROUND(MAX(temp_c), 1) AS peak_temp_c, COUNT(*) AS sample_count
FROM classified WHERE temp_c > 60 GROUP BY sensor_track_id, sensor_name, period_id
HAVING COUNT(*) >= 5 AND MAX(ts)-MIN(ts) >= 3000000000
ORDER BY peak_temp_c DESC
