-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: afbc66c5633332309054bf23e4dc7bbebfec5f12bd9b6b494e68f270b19f8755

SELECT
  COUNT(*) as txn_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM android_binder_txns
WHERE (
    ('${package}' = '' OR client_process = '${package}' OR client_process GLOB '${package}:*')
    OR ('${package}' = '' OR server_process = '${package}' OR server_process GLOB '${package}:*')
    OR '${package}' = ''
  )
  AND (${start_ts} IS NULL OR client_ts + client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR client_ts < ${end_ts})
