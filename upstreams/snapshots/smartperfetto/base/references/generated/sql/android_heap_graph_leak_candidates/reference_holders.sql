-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_heap_graph_leak_candidates.skill.yaml
-- Source SHA-256: e2af69bca6b92ed9ca91e615637c3e86b5fc9daba767af5db4f2ef7225f98f20
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

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
  SELECT
    NULLIF('${class_name_glob|}', '') AS class_name_glob,
    COALESCE(NULLIF('${lifecycle_slice_prefix|SI$}', ''), '') AS lifecycle_prefix,
    MIN(MAX(COALESCE(${max_candidates|50}, 50), 1), 200) AS max_candidates,
    MIN(MAX(COALESCE(${max_reference_edges|100}, 100), 1), 500) AS max_reference_edges
),
heap_objects AS MATERIALIZED (
  SELECT
    o.id AS object_id,
    o.upid,
    o.graph_sample_ts,
    COALESCE(c.deobfuscated_name, c.name) AS class_name,
    o.self_size,
    COALESCE(o.native_size, 0) AS native_size
  -- Real objects of scoped dumps only (no self_size = -1 placeholders).
  FROM heap_graph_scoped_objects o
  JOIN heap_graph_class c ON o.type_id = c.id
  CROSS JOIN input
  WHERE o.reachable = 1
    AND COALESCE(c.deobfuscated_name, c.name) NOT IN (
      'android.app.Activity',
      'android.app.Fragment',
      'androidx.fragment.app.Fragment',
      'androidx.activity.ComponentActivity',
      'androidx.appcompat.app.AppCompatActivity'
    )
    AND (
      COALESCE(c.deobfuscated_name, c.name) GLOB '*Activity'
      OR COALESCE(c.deobfuscated_name, c.name) GLOB '*Activity$*'
      OR COALESCE(c.deobfuscated_name, c.name) GLOB '*Activity_*'
      OR COALESCE(c.deobfuscated_name, c.name) GLOB '*Fragment'
      OR COALESCE(c.deobfuscated_name, c.name) GLOB '*Fragment$*'
      OR COALESCE(c.deobfuscated_name, c.name) GLOB '*Fragment_*'
      OR (input.class_name_glob IS NOT NULL AND COALESCE(c.deobfuscated_name, c.name) GLOB input.class_name_glob)
    )
),
class_candidates AS (
  SELECT
    upid,
    graph_sample_ts,
    class_name,
    COUNT(*) AS reachable_obj_count,
    SUM(self_size) AS self_size_bytes
  FROM heap_objects
  GROUP BY upid, graph_sample_ts, class_name
),
candidate_states AS (
  SELECT
    c.*,
    (
      SELECT
        CASE
          WHEN s.name GLOB '*onDestroyView*' THEN 'destroyed'
          WHEN s.name GLOB '*onDestroy*' THEN 'destroyed'
          WHEN s.name GLOB '*onPause*' THEN 'inactive'
          WHEN s.name GLOB '*onStop*' THEN 'inactive'
          WHEN s.name GLOB '*onResume*' THEN 'active'
          WHEN s.name GLOB '*onStart*' THEN 'active'
          WHEN s.name GLOB '*onCreate*' THEN 'active'
          ELSE 'unknown'
        END
      FROM slice s
      JOIN thread_track tt ON s.track_id = tt.id
      JOIN thread t ON tt.utid = t.utid
      JOIN process p ON t.upid = p.upid
      CROSS JOIN input
      WHERE p.upid = c.upid
        AND s.dur >= 0
        AND s.ts + s.dur <= c.graph_sample_ts
        AND (
          (input.lifecycle_prefix = '' AND s.name GLOB '*' || c.class_name || '.*')
          OR (input.lifecycle_prefix != '' AND s.name GLOB input.lifecycle_prefix || c.class_name || '.*')
        )
        AND (
          s.name GLOB '*onCreate*' OR s.name GLOB '*onStart*' OR s.name GLOB '*onResume*'
          OR s.name GLOB '*onPause*' OR s.name GLOB '*onStop*'
          OR s.name GLOB '*onDestroy*' OR s.name GLOB '*onDestroyView*'
        )
      ORDER BY s.ts DESC
      LIMIT 1
    ) AS lifecycle_phase_at_sample
  FROM class_candidates c
),
suspect_classes AS (
  SELECT
    *,
    CASE
      WHEN lifecycle_phase_at_sample = 'destroyed' THEN 'destroyed_reachable'
      WHEN reachable_obj_count > 1 THEN 'multi_instance_reachable'
      ELSE 'not_suspect'
    END AS leak_state
  FROM candidate_states
  WHERE lifecycle_phase_at_sample = 'destroyed'
    OR reachable_obj_count > 1
  ORDER BY
    CASE WHEN lifecycle_phase_at_sample = 'destroyed' THEN 0 ELSE 1 END,
    self_size_bytes DESC,
    reachable_obj_count DESC
  LIMIT (SELECT max_candidates FROM input)
),
suspect_objects AS (
  SELECT
    h.*,
    sc.leak_state
  FROM heap_objects h
  JOIN suspect_classes sc
    ON sc.upid = h.upid
    AND sc.graph_sample_ts = h.graph_sample_ts
    AND sc.class_name = h.class_name
)
SELECT
  d.process_name,
  printf('%d', so.graph_sample_ts) AS graph_sample_ts,
  so.class_name AS candidate_class,
  so.object_id AS owned_object_id,
  COALESCE(owner_class.deobfuscated_name, owner_class.name, printf('owner:%d', ref.owner_id)) AS owner_class,
  COALESCE(CASE
    WHEN ref.deobfuscated_field_name IS NOT NULL AND ref.deobfuscated_field_name != ref.field_name THEN ref.deobfuscated_field_name
    ELSE ref.field_name
  END, '<unknown>') AS field_display,
  ref.field_type_name,
  so.leak_state
FROM suspect_objects so
JOIN heap_graph_dump_scope d USING (upid, graph_sample_ts)
JOIN heap_graph_reference ref
  ON ref.owned_id = so.object_id
  AND ref.id NOT IN _excluded_refs
JOIN heap_graph_object owner_obj
  ON owner_obj.id = ref.owner_id
  AND owner_obj.reachable = 1
LEFT JOIN heap_graph_class owner_class ON owner_obj.type_id = owner_class.id
WHERE ref.owner_id IS NOT NULL
ORDER BY
  CASE so.leak_state WHEN 'destroyed_reachable' THEN 0 ELSE 1 END,
  so.class_name,
  so.object_id
LIMIT (SELECT max_reference_edges FROM input)
