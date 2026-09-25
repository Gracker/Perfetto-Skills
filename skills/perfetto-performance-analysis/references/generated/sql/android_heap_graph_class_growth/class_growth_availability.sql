-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_heap_graph_class_growth.skill.yaml
-- Source SHA-256: 7f3005702a7a0b160c86748bb1b535119fb9647f5d1bfa60496bf33c11551a55
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Process scope shared by the heap graph, heapprofd and Bitmap Skills.
-- Candidates are processes that have heap data (a heap graph dump or heapprofd
-- allocations) or Bitmap memory counters (atrace "view"), so a trace with only
-- Bitmap counters still has candidates. Consumers join their own data to
-- heap_target_process, so a candidate without that data adds no rows.
-- Rule, in order:
--   1. An explicit upid selects exactly that process.
--   2. process_name (or package) matches a process name exactly or as its
--      `name:*` subprocess. There is no substring matching, so `com.foo` never
--      selects `com.foobar`.
--   3. When a name was given and no candidate matches, heap graph/heapprofd
--      candidates without a process name are used instead (an .hprof dump has
--      none) and flagged process_name_unavailable_upid_fallback; they are never
--      silently dropped. A Bitmap-counter-only process never takes this
--      fallback, but a name matching it does count as a match.
--   4. With no upid and no name every candidate is in scope.
heap_target_input AS (
  SELECT
    ${upid} AS target_upid,
    COALESCE(NULLIF('${process_name|}', ''), NULLIF('${package|}', ''), '') AS target_name
),
heap_data_processes AS (
  SELECT upid, MAX(has_heap_dump) AS has_heap_dump
  FROM (
    SELECT upid, 1 AS has_heap_dump FROM heap_graph
    UNION ALL
    SELECT DISTINCT upid, 1 AS has_heap_dump FROM heap_profile_allocation
    UNION ALL
    SELECT upid, 0 AS has_heap_dump FROM process_counter_track
    WHERE name IN ('Bitmap Memory', 'Bitmap Count')
  )
  GROUP BY upid
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
      OR (p.name IS NULL AND d.has_heap_dump AND NOT EXISTS (SELECT 1 FROM heap_target_name_matches))
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
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Dumps a Skill reports per-dump rows for, chosen by dump_selector: latest
-- (last dump of each process, the default), first, or all. Unknown values
-- fall back to latest; heap_graph_dump_selector exposes the applied value.
-- Requires fragments/heap_target_process.sql and
-- fragments/heap_graph_dump_scope.sql before it.
heap_graph_dump_selector AS (
  SELECT
    CASE lower(trim('${dump_selector|latest}'))
      WHEN 'first' THEN 'first'
      WHEN 'all' THEN 'all'
      ELSE 'latest'
    END AS dump_selector
),
heap_graph_indexed_dumps AS (
  SELECT
    d.*,
    ROW_NUMBER() OVER (PARTITION BY d.upid ORDER BY d.graph_sample_ts) AS dump_index,
    ROW_NUMBER() OVER (PARTITION BY d.upid ORDER BY d.graph_sample_ts DESC) AS reverse_index
  FROM heap_graph_dump_scope AS d
),
heap_graph_selected_dumps AS (
  SELECT
    d.*,
    CASE s.dump_selector
      WHEN 'all' THEN 1
      WHEN 'first' THEN d.dump_index = 1
      ELSE d.reverse_index = 1
    END AS selected_for_ranking
  FROM heap_graph_indexed_dumps AS d
  CROSS JOIN heap_graph_dump_selector AS s
)
,
per_process AS (
  SELECT upid, COUNT(*) AS dumps FROM heap_graph_dump_scope GROUP BY upid
)
SELECT
  (SELECT COUNT(*) FROM heap_graph_dump_scope) AS dump_count,
  (SELECT COUNT(*) FROM per_process) AS process_count,
  COALESCE((SELECT MAX(dumps) FROM per_process), 0) AS max_dumps_per_process,
  (SELECT COUNT(*) FROM heap_graph_dump_scope WHERE dump_completeness = 'incomplete_dump') AS incomplete_dump_count,
  (SELECT dump_selector FROM heap_graph_dump_selector) AS dump_selector,
  COALESCE((SELECT GROUP_CONCAT(DISTINCT process_identity) FROM heap_graph_dump_scope), 'none') AS process_identity,
  CASE
    WHEN COALESCE((SELECT MAX(dumps) FROM per_process), 0) >= 2 THEN 'multiple_dumps'
    WHEN EXISTS (SELECT 1 FROM heap_graph_dump_scope) THEN 'single_dump'
    WHEN EXISTS (SELECT 1 FROM heap_graph) THEN 'no_heap_graph_for_requested_process'
    ELSE 'no_heap_graph_data'
  END AS status
