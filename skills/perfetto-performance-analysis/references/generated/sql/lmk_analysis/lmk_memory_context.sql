-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 380a21355baca5f8e2d2d740174e6f6897b0150f4d792c53f3b0d42de71a0f1b
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

WITH lmk_events AS (
  SELECT ts, process_name, kill_reason
  FROM android_lmk_events
  WHERE CASE WHEN '${package}' != ''
             THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
             ELSE 1 END
    AND (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
  ORDER BY ts
  LIMIT 10
)
SELECT
  printf('%d', le.ts) AS lmk_ts,
  le.process_name,
  le.kill_reason,
  ROUND((
    SELECT value / 1024 / 1024
    FROM counter c
    JOIN counter_track ct ON c.track_id = ct.id
    WHERE ct.name = 'mem.free'
      AND c.ts <= le.ts
    ORDER BY c.ts DESC
    LIMIT 1
  ), 1) AS free_mem_mb,
  ROUND((
    SELECT value / 1024 / 1024
    FROM counter c
    JOIN counter_track ct ON c.track_id = ct.id
    WHERE ct.name = 'mem.available'
      AND c.ts <= le.ts
    ORDER BY c.ts DESC
    LIMIT 1
  ), 1) AS available_mem_mb
FROM lmk_events le
