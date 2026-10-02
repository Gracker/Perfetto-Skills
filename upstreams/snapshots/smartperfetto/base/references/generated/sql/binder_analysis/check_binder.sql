-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: fc34e062a7ce8185abceac60b9171ac039d0e631ee0ef1646f3d6ef0369cbeee

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
