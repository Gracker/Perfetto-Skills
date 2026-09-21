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
thermal_peak AS (
  SELECT MAX(temp_c) AS peak_temp_c FROM thermal_valid_samples
),
thermal_quality AS (
  SELECT COUNT(*) AS track_count,
    SUM(CASE WHEN sample_quality != 'accepted' THEN 1 ELSE 0 END) AS rejected_tracks,
    MAX(CASE WHEN sample_quality = 'accepted' THEN raw_max_temp_c END)
    - MIN(CASE WHEN sample_quality = 'accepted' THEN raw_max_temp_c END) AS sensor_spread_c
  FROM thermal_track_stats
),
cpu_freq_stats AS (
  SELECT
    cct.cpu as cpu_id,
    MIN(c.value / 1000.0) as min_freq_mhz,
    MAX(c.value / 1000.0) as max_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name = 'cpufreq'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
  GROUP BY cct.cpu
),
throttled_cpus AS (
  SELECT COUNT(*) as cnt
  FROM cpu_freq_stats
  WHERE min_freq_mhz < max_freq_mhz * 0.5
),
freq_drops AS (
  SELECT COUNT(*) as cnt
  FROM (
    SELECT
      cct.cpu,
      c.value / 1000.0 as freq_mhz,
      LAG(c.value / 1000.0) OVER (PARTITION BY cct.cpu ORDER BY c.ts) as prev_freq
    FROM counter c
    JOIN cpu_counter_track cct ON c.track_id = cct.id
    WHERE cct.name = 'cpufreq'
      AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
      AND (${end_ts} IS NULL OR c.ts < ${end_ts})
  ) sub
  WHERE prev_freq IS NOT NULL AND freq_mhz < prev_freq * 0.7
)
SELECT
  CASE WHEN (SELECT rejected_tracks FROM thermal_quality) > 0
      OR (SELECT sensor_spread_c FROM thermal_quality) > 30 THEN 'DATA_SUSPECT'
    WHEN (SELECT peak_temp_c FROM thermal_peak) IS NULL THEN 'THERMAL_DATA_UNAVAILABLE'
    WHEN (SELECT peak_temp_c FROM thermal_peak) > 60 THEN 'HIGH_TEMP_OBSERVED'
    WHEN (SELECT cnt FROM freq_drops) > 10 THEN 'FREQ_INSTABILITY'
    ELSE 'THERMAL_NORMAL' END AS classification,
  ROUND((SELECT peak_temp_c FROM thermal_peak), 1) AS peak_temp_c,
  NULL AS throttled_cpu_count,
  (SELECT cnt FROM throttled_cpus) AS frequency_variation_cpu_count,
  (SELECT cnt FROM freq_drops) AS severe_drop_count,
  (SELECT rejected_tracks FROM thermal_quality) AS rejected_temperature_tracks,
  ROUND((SELECT sensor_spread_c FROM thermal_quality), 1) AS sensor_spread_c,
  'not_established' AS thermal_throttling_evidence,
  CASE WHEN (SELECT rejected_tracks FROM thermal_quality) > 0
    THEN '温度数据可疑：已排除低质量轨道；峰值仅代表有效传感器，不代表 CPU 结温。'
    WHEN (SELECT sensor_spread_c FROM thermal_quality) > 30
    THEN '传感器温差较大：皮肤和结温不可直接比较，需核对位置、单位及时间覆盖。'
    WHEN (SELECT peak_temp_c FROM thermal_peak) IS NULL THEN '温度数据不可用，不能判断热状态。'
    WHEN (SELECT peak_temp_c FROM thermal_peak) > 60 THEN '有效传感器观测到高温，不代表持续高温或热节流。'
    ELSE '有效传感器未见高温；频率变化可由负载或空闲 DVFS 引起，不能据此确定热节流。'
  END AS description
