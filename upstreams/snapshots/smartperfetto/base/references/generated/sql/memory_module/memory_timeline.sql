-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: 414d1472ca7ef5f999ad8066cb1322622316c622e4bb29e5d0ce7f7b0e4fad9b
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

WITH
time_range AS (
  SELECT MIN(ts) as start_ts, MAX(ts) as end_ts FROM counter
),
mem_samples AS (
  SELECT
    CAST((c.ts - (SELECT start_ts FROM time_range)) / 1e9 AS INTEGER) AS time_sec,
    ct.name AS memory_type,
    c.value / 1024 / 1024 AS value_mb
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE ct.name LIKE '%MemAvailable%'
    OR ct.name LIKE '%MemFree%'
)
SELECT
  time_sec,
  memory_type,
  CAST(AVG(value_mb) AS INTEGER) AS avg_mb
FROM mem_samples
GROUP BY time_sec, memory_type
ORDER BY time_sec
LIMIT 120
