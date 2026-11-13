-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/buffer_transaction_lifecycle.skill.yaml
-- Source SHA-256: 977f9ee7b1e356090321193837d29dbd067b40b9ba43929e9c297508292d5421

WITH event_inventory AS (
  SELECT s.name, p.name AS process_name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE s.ts >= ${start_ts} AND s.ts < ${end_ts}
),
sf_events AS (
  SELECT name FROM event_inventory
  WHERE process_name = 'surfaceflinger'
    OR process_name GLOB '*/surfaceflinger'
),
app_events AS (
  SELECT name FROM event_inventory
  WHERE '${package|}' = ''
    OR process_name = '${package|}'
    OR SUBSTR(process_name, 1, LENGTH('${package|}') + 1) = '${package|}:'
)
SELECT
  (SELECT COUNT(*) FROM sf_events WHERE name GLOB '*applyTransaction*') AS total_apply_transactions,
  (SELECT COUNT(*) FROM sf_events WHERE name GLOB '*setTransactionState*') AS total_set_transaction_state,
  (SELECT COUNT(*) FROM app_events WHERE name GLOB '*BLASTBufferQueue*') AS total_blast_bq,
  (SELECT COUNT(*) FROM app_events WHERE name GLOB 'queueBuffer*' OR name GLOB '*::queueBuffer*') AS total_queue_buffer,
  CAST(NULL AS REAL) AS avg_apply_to_latch_ms,
  'unsupported_missing_identity' AS pairing_status,
  'global_surfaceflinger' AS sf_event_scope,
  CASE WHEN '${package|}' = '' THEN 'all_processes'
    ELSE 'package_and_colon_subprocesses' END AS app_event_scope
