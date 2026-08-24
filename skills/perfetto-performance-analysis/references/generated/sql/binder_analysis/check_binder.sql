-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: d005054dab0e8c6ea08c377ca3407e935fb7134f30aa318211845cf32f3e2a0a
-- Source commit: 9d0d444f8891a0fc47d7ede0da6ef5f758f9ede4

SELECT
  COUNT(*) as txn_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM android_binder_txns
WHERE (
    client_process GLOB '${package}*'
    OR server_process GLOB '${package}*'
    OR '${package}' = ''
  )
  AND (${start_ts} IS NULL OR client_ts + client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR client_ts < ${end_ts})
