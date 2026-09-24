-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: bb2e6b53cdde9eef70dca527316ceb2d87cdaed5c609cafd9ec516f76b3cd770
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Process scope shared by the heap graph and heapprofd Skills. Candidates are
-- processes that have heap data (a heap graph dump or heapprofd allocations).
-- Rule, in order:
--   1. An explicit upid selects exactly that process.
--   2. process_name (or package) matches a process name exactly or as its
--      `name:*` subprocess. There is no substring matching, so `com.foo` never
--      selects `com.foobar`.
--   3. When a name was given and no candidate matches, candidates without a
--      process name are used instead (an .hprof dump has none) and flagged
--      process_name_unavailable_upid_fallback; they are never silently dropped.
--   4. With no upid and no name every candidate is in scope.
heap_target_input AS (
  SELECT
    ${upid} AS target_upid,
    COALESCE(NULLIF('${process_name|}', ''), NULLIF('${package|}', ''), '') AS target_name
),
heap_data_processes AS (
  SELECT upid FROM heap_graph
  UNION
  SELECT DISTINCT upid FROM heap_profile_allocation
),
heap_target_name_matches AS (
  SELECT d.upid
  FROM heap_data_processes AS d
  JOIN process AS p USING (upid)
  CROSS JOIN heap_target_input AS i
  WHERE i.target_name != ''
    AND (p.name = i.target_name OR p.name GLOB i.target_name || ':*')
),
heap_target_process AS (
  SELECT
    d.upid,
    COALESCE(p.name, printf('upid:%d', d.upid)) AS process_name,
    CASE
      WHEN i.target_upid IS NOT NULL THEN 'upid_selected'
      WHEN i.target_name = '' THEN 'all_heap_processes'
      WHEN m.upid IS NOT NULL THEN 'process_name_match'
      ELSE 'process_name_unavailable_upid_fallback'
    END AS process_identity
  FROM heap_data_processes AS d
  CROSS JOIN heap_target_input AS i
  LEFT JOIN process AS p USING (upid)
  LEFT JOIN heap_target_name_matches AS m USING (upid)
  WHERE (i.target_upid IS NOT NULL AND d.upid = i.target_upid)
    OR (i.target_upid IS NULL AND (
      i.target_name = ''
      OR m.upid IS NOT NULL
      OR (p.name IS NULL AND NOT EXISTS (SELECT 1 FROM heap_target_name_matches))
    ))
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Heap graph dumps in scope, one row per (upid, graph_sample_ts). Requires
-- fragments/heap_target_process.sql before it (process rule lives there).
-- An incomplete dump (packet loss, non-finalized graph) keeps forward
-- references as placeholder objects with self_size = -1, typed with class id
-- 0; they are counted here per scoped dump and never read as real objects.
-- dump_issues lists heap_graph/hprof error or data-loss stats for the process
-- (or global ones); either signal marks the dump incomplete, so its sizes and
-- counts are lower bounds.
heap_graph_dump_scope AS MATERIALIZED (
  SELECT
    d.*,
    CASE
      WHEN d.placeholder_object_count > 0 OR d.dump_issues IS NOT NULL THEN 'incomplete_dump'
      ELSE 'no_incompleteness_signal'
    END AS dump_completeness
  FROM (
    SELECT
      h.upid,
      h.ts AS graph_sample_ts,
      t.process_name,
      t.process_identity,
      COALESCE(ph.placeholder_object_count, 0) AS placeholder_object_count,
      (
        SELECT GROUP_CONCAT(s.name || '=' || s.value, ', ')
        FROM stats AS s
        WHERE (s.name GLOB 'heap_graph*' OR s.name GLOB 'hprof*')
          AND s.severity IN ('error', 'data_loss')
          AND s.value > 0
          AND (s.idx = h.upid OR s.idx IS NULL)
      ) AS dump_issues
    FROM heap_graph AS h
    JOIN heap_target_process AS t USING (upid)
    -- One pass over the object table for every dump, not one per dump.
    LEFT JOIN (
      SELECT upid, graph_sample_ts, COUNT(*) AS placeholder_object_count
      FROM heap_graph_object
      WHERE self_size = -1
      GROUP BY upid, graph_sample_ts
    ) AS ph
      ON ph.upid = h.upid
      AND ph.graph_sample_ts = h.ts
    WHERE ${graph_sample_ts} IS NULL OR h.ts = ${graph_sample_ts}
  ) AS d
),
-- The only read path for heap objects: real objects of scoped dumps, so no
-- sum or count can include a placeholder.
heap_graph_scoped_objects AS (
  SELECT o.*
  FROM heap_graph_object AS o
  JOIN heap_graph_dump_scope AS d
    ON d.upid = o.upid
    AND d.graph_sample_ts = o.graph_sample_ts
  WHERE o.self_size >= 0
)
,
input AS (
  SELECT MIN(MAX(COALESCE(${max_rows|40}, 40), 1), 500) AS max_rows
)
SELECT
  d.process_name,
  printf('%d', h.graph_sample_ts) AS graph_sample_ts,
  h.name AS class_name,
  COALESCE(h.root_type, '') AS root_type,
  COUNT(*) AS path_count,
  SUM(h.self_count) AS total_objects,
  ROUND(SUM(h.cumulative_size) / 1048576.0, 2) AS total_retained_mb,
  MIN(h.self_size) AS single_object_self_size,
  MIN(h.cumulative_size) AS single_object_cumulative_size
FROM android_heap_graph_class_summary_tree AS h
JOIN heap_graph_dump_scope AS d USING (upid, graph_sample_ts)
GROUP BY h.upid, h.graph_sample_ts, h.name, h.root_type
ORDER BY path_count DESC, total_objects DESC, total_retained_mb DESC
LIMIT (SELECT max_rows FROM input)
