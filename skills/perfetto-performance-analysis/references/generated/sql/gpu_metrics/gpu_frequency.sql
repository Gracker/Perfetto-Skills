-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_metrics.skill.yaml
-- Source SHA-256: 7ec44d892abb05141d0c58bfb05944911a22d8a6d4252fc95aa9b12c5f4f800a
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(c.ts)) as start_ts,
    COALESCE(${end_ts}, MAX(c.ts)) as end_ts
  FROM counter c
),
gpu_freq AS (
  SELECT
    c.ts,
    CASE
      -- 优先使用 counter_track 的 unit 字段判断单位
      WHEN t.unit = 'MHz' THEN c.value
      WHEN t.unit = 'kHz' THEN c.value / 1000.0
      WHEN t.unit = 'Hz' THEN c.value / 1000000.0
      -- unit 为空时使用 heuristic 推断
      WHEN c.value > 1000000 THEN c.value / 1000000.0
      WHEN c.value > 1000 THEN c.value / 1000.0
      ELSE c.value
    END as freq_mhz,
    t.name as counter_name
  FROM counter c
  JOIN gpu_counter_track t ON c.track_id = t.id
  WHERE (t.name GLOB '*freq*' OR t.name GLOB '*Freq*' OR t.name GLOB '*clock*')
    AND c.ts >= (SELECT start_ts FROM time_bounds)
    AND c.ts <= (SELECT end_ts FROM time_bounds)
)
SELECT
  ROUND(AVG(freq_mhz), 0) as avg_freq_mhz,
  ROUND(MAX(freq_mhz), 0) as max_freq_mhz,
  ROUND(MIN(freq_mhz), 0) as min_freq_mhz,
  ROUND(PERCENTILE(freq_mhz, 0.5), 0) as median_freq_mhz,
  COUNT(*) as sample_count,
  (SELECT GROUP_CONCAT(DISTINCT counter_name) FROM gpu_freq) as freq_counters
FROM gpu_freq
WHERE freq_mhz > 0
