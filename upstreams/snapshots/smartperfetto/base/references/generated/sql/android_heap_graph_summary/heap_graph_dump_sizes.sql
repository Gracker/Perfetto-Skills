-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_heap_graph_summary.skill.yaml
-- Source SHA-256: de6251b10137d1d773f7eef2c440c14fbe12fc4312d3dee7872e20ec632eb0e8
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

-- One scan of the object table for every step below; placeholder
-- objects (self_size = -1) are not real objects and are excluded.
CREATE OR REPLACE PERFETTO TABLE __sp_heap_graph_dump_sizes AS
SELECT
  upid,
  graph_sample_ts,
  COUNT(*) AS object_count,
  SUM(self_size) AS total_heap_size,
  SUM(IIF(reachable, self_size, 0)) AS reachable_heap_size,
  SUM(IIF(reachable, 1, 0)) AS reachable_obj_count
FROM heap_graph_object
WHERE self_size >= 0
GROUP BY upid, graph_sample_ts;

SELECT COUNT(*) AS dump_count FROM __sp_heap_graph_dump_sizes
