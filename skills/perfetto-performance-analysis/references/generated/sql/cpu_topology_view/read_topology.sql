-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_topology_view.skill.yaml
-- Source SHA-256: 71bcdc2a2f2b3c8688412e9a48c716ff4e008e01da9728347161d071b302c67a
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  cpu_id,
  universe_source,
  capacity,
  CASE WHEN max_freq IS NULL THEN NULL ELSE ROUND(max_freq / 1000.0, 0) END as max_freq_mhz,
  scale_value,
  scale_bucket,
  core_type,
  topology_source,
  cluster_rank,
  cluster_count,
  cores_in_cluster
FROM _cpu_topology
ORDER BY cpu_id
