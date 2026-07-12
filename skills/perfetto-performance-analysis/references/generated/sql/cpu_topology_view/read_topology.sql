-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_topology_view.skill.yaml
-- Source SHA-256: 792f8e08be59730e2b62f9f21359ea7677b02b8ab7aa5224e5caaa9587779f76
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

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
