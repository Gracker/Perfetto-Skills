-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/native_heap_breakdown.skill.yaml
-- Source SHA-256: c60782edef05f79ebd9a79e7f0f8f3f2dfec35cd35c839c661f0f34a68681fff
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

WITH RECURSIVE
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

-- heapprofd allocations of scoped processes, per (upid, heap_name). Requires
-- fragments/heap_target_process.sql before it. Negative size/count rows are
-- frees: SUM(size) is unreleased bytes, SUM(MAX(size, 0)) is allocated bytes.
-- retention_measurable is the single definition of whether unreleased bytes
-- mean anything: libc.malloc records every free, other heaps only if frees
-- were observed, and com.android.art Java allocation profiles never record GC
-- frees (unreleased == allocated by construction), so they are churn only.
heap_profile_callsites AS MATERIALIZED (
  SELECT
    a.upid,
    a.heap_name,
    a.callsite_id,
    SUM(a.size) AS unreleased_bytes,
    SUM(MAX(a.size, 0)) AS alloc_bytes,
    SUM(a.count) AS unreleased_count,
    SUM(MAX(a.count, 0)) AS alloc_count,
    SUM(a.size < 0) AS free_records
  FROM heap_profile_allocation AS a
  JOIN heap_target_process USING (upid)
  GROUP BY a.upid, a.heap_name, a.callsite_id
),
heap_profiles AS (
  SELECT
    upid,
    heap_name,
    SUM(unreleased_bytes) AS unreleased_bytes,
    SUM(alloc_bytes) AS alloc_bytes,
    SUM(unreleased_count) AS unreleased_count,
    SUM(alloc_count) AS alloc_count,
    SUM(free_records) AS free_records,
    heap_name = 'libc.malloc'
      OR (heap_name != 'com.android.art' AND SUM(free_records) > 0) AS retention_measurable
  FROM heap_profile_callsites
  GROUP BY upid, heap_name
)
,
input AS (
  SELECT
    COALESCE(${min_size_mb|1}, 1) AS min_size_mb,
    COALESCE(${min_alloc_mb|0}, 0) AS min_alloc_mb,
    MIN(MAX(COALESCE(${max_rows|100}, 100), 1), 500) AS max_rows,
    -- heapprofd default Poisson sampling interval; differences within one
    -- interval are sampling noise, not retention.
    4096 AS sampling_interval_bytes
),
-- ART runtime, Bionic libc/libc++ and JIT trampolines are allocator
-- internals shared by every call site; classified once per mapping.
runtime_mappings AS MATERIALIZED (
  SELECT
    id,
    (
      name GLOB '/apex/com.android.art/*'
      OR name GLOB '/apex/com.android.runtime/*'
      OR name GLOB '/[[]anon_shmem:dalvik-jit-code-cache]*'
      OR name GLOB '/system/lib*/libc.so'
      OR name GLOB '/system/lib*/libc++.so'
      OR name GLOB '/system/lib*/libart.so'
    ) AS is_runtime
  FROM stack_profile_mapping
),
-- Walk each sampled callsite from its leaf frame to the root. Inline
-- symbols are expanded by the stdlib forest. (Join, not IN: IN on this
-- forest callsite_id aborts trace_processor v58.3-99234d73f.)
frame_chain(callsite_id, node_id, depth) AS (
  SELECT DISTINCT f.callsite_id, f.id, 0
  FROM _callstack_spc_forest AS f
  JOIN (SELECT DISTINCT callsite_id FROM heap_profile_callsites) AS used
    ON used.callsite_id = f.callsite_id
  WHERE f.is_leaf_function_in_callsite_frame
  UNION ALL
  SELECT c.callsite_id, f.parent_id, c.depth + 1
  FROM frame_chain AS c
  JOIN _callstack_spc_forest AS f ON f.id = c.node_id
  WHERE f.parent_id IS NOT NULL
),
chain_frames AS MATERIALIZED (
  SELECT
    c.callsite_id,
    c.depth,
    COALESCE(f.name, '[unknown]') AS name,
    COALESCE(m.name, '') AS mapping_name,
    f.source_file,
    COALESCE(rm.is_runtime, 0) AS is_runtime
  FROM frame_chain AS c
  JOIN _callstack_spc_forest AS f ON f.id = c.node_id
  LEFT JOIN stack_profile_mapping AS m ON m.id = f.mapping_id
  LEFT JOIN runtime_mappings AS rm ON rm.id = f.mapping_id
),
attribution AS MATERIALIZED (
  SELECT
    callsite_id,
    COALESCE(MIN(IIF(is_runtime, NULL, depth)), 0) AS attributed_depth
  FROM chain_frames
  GROUP BY callsite_id
),
attributed AS (
  SELECT
    a.upid,
    a.heap_name,
    cf.name,
    cf.mapping_name,
    MIN(cf.source_file) AS source_file,
    SUM(a.unreleased_bytes) AS unreleased_bytes,
    SUM(a.alloc_bytes) AS alloc_bytes,
    SUM(a.alloc_count) AS alloc_count
  FROM heap_profile_callsites AS a
  JOIN attribution AS at USING (callsite_id)
  JOIN chain_frames AS cf
    ON cf.callsite_id = a.callsite_id
    AND cf.depth = at.attributed_depth
  GROUP BY a.upid, a.heap_name, cf.name, cf.mapping_name
),
-- Frames that count toward cumulative totals: every non-runtime frame,
-- once per callstack (recursion), plus the attributed fallback frame.
callsite_labels AS (
  SELECT DISTINCT cf.callsite_id, cf.name, cf.mapping_name
  FROM chain_frames AS cf
  JOIN attribution AS at USING (callsite_id)
  WHERE NOT cf.is_runtime OR cf.depth = at.attributed_depth
),
cumulative AS MATERIALIZED (
  SELECT
    a.upid,
    a.heap_name,
    l.name,
    l.mapping_name,
    SUM(a.unreleased_bytes) AS unreleased_bytes,
    SUM(a.alloc_bytes) AS alloc_bytes,
    SUM(a.unreleased_count) AS unreleased_count,
    SUM(a.alloc_count) AS alloc_count
  FROM heap_profile_callsites AS a
  JOIN callsite_labels AS l USING (callsite_id)
  GROUP BY a.upid, a.heap_name, l.name, l.mapping_name
),
label_edges AS (
  SELECT DISTINCT
    a.upid,
    a.heap_name,
    e.parent_name,
    e.parent_mapping,
    e.name,
    e.mapping_name
  FROM (
    SELECT
      callsite_id,
      name,
      mapping_name,
      LEAD(name) OVER w AS parent_name,
      LEAD(mapping_name) OVER w AS parent_mapping
    FROM chain_frames
    WHERE NOT is_runtime
    WINDOW w AS (PARTITION BY callsite_id ORDER BY depth)
  ) AS e
  JOIN heap_profile_callsites AS a USING (callsite_id)
  WHERE e.parent_name IS NOT NULL
    AND NOT (e.parent_name = e.name AND e.parent_mapping = e.mapping_name)
),
-- Pass-through wrappers (main -> ZygoteInit -> Looper ...) whose totals
-- are fully accounted for by one child frame.
pass_through AS (
  SELECT DISTINCT e.upid, e.heap_name, e.parent_name AS name, e.parent_mapping AS mapping_name
  FROM label_edges AS e
  JOIN cumulative AS parent
    ON parent.upid = e.upid
    AND parent.heap_name = e.heap_name
    AND parent.name = e.parent_name
    AND parent.mapping_name = e.parent_mapping
  JOIN cumulative AS child
    ON child.upid = e.upid
    AND child.heap_name = e.heap_name
    AND child.name = e.name
    AND child.mapping_name = e.mapping_name
  WHERE parent.unreleased_bytes = child.unreleased_bytes
    AND parent.alloc_bytes = child.alloc_bytes
    AND parent.unreleased_count = child.unreleased_count
    AND parent.alloc_count = child.alloc_count
),
ranked AS (
  SELECT
    c.upid,
    c.heap_name,
    c.name,
    c.mapping_name,
    COALESCE(s.unreleased_bytes, 0) AS self_unreleased_bytes,
    COALESCE(s.alloc_bytes, 0) AS self_alloc_bytes,
    COALESCE(s.alloc_count, 0) AS self_alloc_count,
    c.unreleased_bytes AS cumulative_unreleased_bytes,
    c.alloc_bytes AS cumulative_alloc_bytes,
    s.source_file,
    p.retention_measurable
  FROM cumulative AS c
  JOIN heap_profiles AS p USING (upid, heap_name)
  LEFT JOIN attributed AS s USING (upid, heap_name, name, mapping_name)
  LEFT JOIN pass_through AS pt USING (upid, heap_name, name, mapping_name)
  WHERE pt.name IS NULL OR s.alloc_bytes > 0
)
SELECT
  r.upid,
  t.process_name,
  r.heap_name,
  r.name,
  r.mapping_name,
  -- Unreleased metrics are only meaningful where frees are recorded.
  IIF(r.retention_measurable, ROUND(r.cumulative_unreleased_bytes / 1048576.0, 2), NULL) AS cumulative_size_mb,
  IIF(r.retention_measurable, ROUND(r.self_unreleased_bytes / 1048576.0, 2), NULL) AS self_size_mb,
  ROUND(r.cumulative_alloc_bytes / 1048576.0, 2) AS cumulative_alloc_mb,
  ROUND(r.self_alloc_bytes / 1048576.0, 2) AS self_alloc_mb,
  r.self_alloc_count,
  IIF(r.retention_measurable, ROUND(100.0 * r.cumulative_unreleased_bytes / NULLIF(r.cumulative_alloc_bytes, 0), 2), NULL) AS unreleased_to_alloc_pct,
  IIF(r.retention_measurable, ROUND(1.0 * r.cumulative_alloc_bytes / NULLIF(r.cumulative_unreleased_bytes, 0), 2), NULL) AS churn_ratio,
  CASE
    WHEN r.self_alloc_bytes = 0 THEN 'call_path_ancestor'
    WHEN NOT r.retention_measurable THEN
      IIF(r.self_alloc_bytes >= MAX(input.min_alloc_mb, input.min_size_mb) * 1048576.0,
        'allocation_churn', 'inspect_if_relevant')
    WHEN r.self_unreleased_bytes >= input.min_size_mb * 1048576.0
      AND r.self_unreleased_bytes > input.sampling_interval_bytes
      AND r.self_alloc_bytes >= r.self_unreleased_bytes * 5
      THEN 'retention_with_churn'
    WHEN r.self_unreleased_bytes >= input.min_size_mb * 1048576.0
      AND r.self_unreleased_bytes > input.sampling_interval_bytes
      THEN 'unreleased_native_retention'
    WHEN input.min_alloc_mb > 0
      AND r.self_alloc_bytes >= input.min_alloc_mb * 1048576.0
      THEN 'allocation_churn'
    ELSE 'inspect_if_relevant'
  END AS native_signal,
  r.source_file
FROM ranked AS r
CROSS JOIN input
JOIN heap_target_process AS t USING (upid)
WHERE (r.retention_measurable AND r.cumulative_unreleased_bytes >= input.min_size_mb * 1048576.0)
  OR r.cumulative_alloc_bytes >= MAX(input.min_alloc_mb, input.min_size_mb) * 1048576.0
ORDER BY
  r.self_alloc_bytes > 0 DESC,
  IIF(r.retention_measurable, r.self_unreleased_bytes, r.self_alloc_bytes) DESC,
  r.self_alloc_bytes DESC,
  r.cumulative_alloc_bytes DESC
LIMIT (SELECT max_rows FROM input)
