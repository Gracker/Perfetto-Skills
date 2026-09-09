-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_analysis.skill.yaml
-- Source SHA-256: f90f3f0875d47fdf3dce00d1d5bae735bddb20bd28a917de579b22e5e2c3afd5
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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
