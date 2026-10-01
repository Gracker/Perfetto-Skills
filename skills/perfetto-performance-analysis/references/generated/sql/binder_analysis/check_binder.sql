-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: be42a4750a322322b4d24e8f51e764fd4a4ba09e3c3d943dca53f0ea8eb0971d

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
