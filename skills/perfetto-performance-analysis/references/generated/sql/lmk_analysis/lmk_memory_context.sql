-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 32494b794e68cb6976f27938f66c022758ebf4fcc0826baa535203c36b6aaceb
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH lmk_events AS (
  SELECT ts, process_name, kill_reason
  FROM android_lmk_events
  WHERE CASE WHEN '${package}' != ''
             THEN process_name GLOB '*${package}*'
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
