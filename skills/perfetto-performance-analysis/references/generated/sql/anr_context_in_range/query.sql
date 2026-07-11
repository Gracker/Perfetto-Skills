-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/anr_context_in_range.skill.yaml
-- Source SHA-256: 72ffcd16110748ddcd1ef5a9dc9ebaa508eac40ffac9571fe7a25a4eefe3000c
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH anr_events AS (
  SELECT
    ts,
    process_name,
    pid,
    upid,
    anr_type,
    error_id,
    default_anr_dur_ms,
    NULLIF(anr_dur_ms, 0) AS actual_anr_dur_ms,
    CASE
      WHEN anr_type IN ('INPUT_DISPATCHING_TIMEOUT', 'INPUT_DISPATCHING_TIMEOUT_NO_FOCUSED_WINDOW') THEN 5000
      WHEN anr_type = 'BROADCAST_OF_INTENT' THEN 10000
      WHEN anr_type = 'EXECUTING_SERVICE' THEN 20000
      WHEN anr_type IN ('START_FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_TIMEOUT') THEN 30000
      WHEN anr_type = 'FOREGROUND_SHORT_SERVICE_TIMEOUT' THEN 180000
      WHEN anr_type IN ('JOB_SERVICE_START', 'JOB_SERVICE_STOP', 'JOB_SERVICE_BIND', 'JOB_SERVICE_NOTIFICATION_NOT_PROVIDED') THEN 8000
      WHEN anr_type = 'BIND_APPLICATION' THEN 15000
      -- Perfetto default is NULL for these types. This value is an explicit
      -- low-confidence lookback window so downstream SQL still has bounds.
      WHEN anr_type IN ('CONTENT_PROVIDER_NOT_RESPONDING', 'GPU_HANG', 'APP_TRIGGERED', 'UNKNOWN_ANR_TYPE') THEN 5000
      ELSE 5000
    END AS heuristic_timeout_ms
  FROM android_anrs
  WHERE (
      ('${process_name}' <> '' AND (process_name = '${process_name}' OR process_name GLOB '${process_name}:*'))
      OR ('${package}' <> '' AND (process_name = '${package}' OR process_name GLOB '${package}:*'))
      OR ('${process_name}' = '' AND '${package}' = '')
    )
    AND (anr_type = '${anr_type}' OR '${anr_type}' = '')
),
normalized AS (
  SELECT
    *,
    COALESCE(actual_anr_dur_ms, default_anr_dur_ms, heuristic_timeout_ms) AS timeout_ms,
    CASE
      WHEN actual_anr_dur_ms IS NOT NULL THEN 'actual_anr_duration'
      WHEN default_anr_dur_ms IS NOT NULL THEN 'perfetto_default'
      ELSE 'heuristic_fallback'
    END AS timeout_source
  FROM anr_events
)
SELECT
  printf('%d', ts) as anr_ts,
  printf('%d', CAST(timeout_ms * 1e6 AS INTEGER)) as timeout_ns,
  ROUND(timeout_ms, 2) as timeout_ms,
  timeout_source,
  process_name,
  pid,
  upid,
  anr_type,
  error_id
FROM normalized
ORDER BY ts ASC
LIMIT 1
