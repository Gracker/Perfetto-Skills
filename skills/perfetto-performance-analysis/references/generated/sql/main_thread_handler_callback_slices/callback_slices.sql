-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/main_thread_handler_callback_slices.skill.yaml
-- Source SHA-256: a143b158022ef674ec5b0171ce6e62301fa5e0cc95e2f7a202c82508e7383765
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

INCLUDE PERFETTO MODULE android.slices;

WITH bounds AS (
  SELECT
    MAX(${start_ts}, trace_start()) AS start_ts,
    CASE WHEN ${end_ts} > 0 THEN MIN(${end_ts}, trace_end()) ELSE trace_end() END AS end_ts
),
observed_callbacks AS (
  SELECT
    MAX(s.ts, b.start_ts) AS clipped_ts,
    MIN(s.ts + s.dur, b.end_ts) - MAX(s.ts, b.start_ts) AS clipped_dur,
    s.name AS raw_slice_name,
    android_standardize_slice_name(s.name) AS standardized_slice_name,
    p.name AS process_name,
    t.name AS thread_name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN bounds b
  WHERE t.tid = p.pid
    AND (p.name GLOB '${package}*' OR '${package}' = '')
    AND s.ts < b.end_ts
    AND s.ts + s.dur > b.start_ts
    AND s.dur > 0
    -- Looper dispatch tracing names callbacks as "<Handler class>: <target>".
    -- The required space prevents SurfaceFlinger TransactionHandler:flush...
    -- from being mistaken for an Android message callback.
    AND s.name GLOB '*Handler: *'
    AND s.name NOT GLOB 'TransactionHandler:*'
)
SELECT
  raw_slice_name,
  standardized_slice_name,
  process_name,
  thread_name,
  COUNT(*) AS callback_count,
  ROUND(SUM(clipped_dur) / 1e6, 3) AS total_ms,
  ROUND(AVG(clipped_dur) / 1e6, 3) AS avg_ms,
  ROUND(MAX(clipped_dur) / 1e6, 3) AS max_ms,
  MIN(clipped_ts) AS first_ts,
  MAX(clipped_ts) AS last_ts,
  'observed_callback_execution_only' AS evidence_scope
FROM observed_callbacks
WHERE clipped_dur >= ${min_dur_ns}
GROUP BY raw_slice_name, standardized_slice_name, process_name, thread_name
ORDER BY total_ms DESC
LIMIT ${top_k}
