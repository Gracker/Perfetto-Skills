-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_topology_view.skill.yaml
-- Source SHA-256: 0e28eae312bbe09e5c3cc1e661392ed9e5814768117dbea99569f35bd3565dc6
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

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
