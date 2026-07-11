-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_topology_view.skill.yaml
-- Source SHA-256: 1a730191dd48abb10a07b8d4b95200f4d4b160ae178d037907613bef58910630
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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
