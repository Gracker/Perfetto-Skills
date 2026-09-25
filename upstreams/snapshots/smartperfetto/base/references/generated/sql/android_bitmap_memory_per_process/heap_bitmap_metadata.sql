-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: c60050ad32c18950da78069dabe941919f7dd55aa3df9ac7ad86d51254da582d
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

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
bitmap_rows AS (
  SELECT
    t.process_name,
    t.process_identity,
    b.*
  FROM heap_graph_bitmaps b
  JOIN heap_target_process t USING (upid)
  -- self_size = -1 marks a placeholder of an incomplete dump, not a Bitmap.
  WHERE COALESCE(b.self_size, 0) >= 0
)
SELECT
  process_name,
  COUNT(*) AS bitmap_object_count,
  SUM(CASE WHEN reachable THEN 1 ELSE 0 END) AS reachable_count,
  SUM(COALESCE(native_size, 0) + COALESCE(self_size, 0)) AS total_bytes,
  SUM(COALESCE(native_size, 0)) AS native_bytes,
  SUM(COALESCE(self_size, 0)) AS java_self_bytes,
  SUM(CASE WHEN width IS NOT NULL AND height IS NOT NULL THEN 1 ELSE 0 END) AS known_dimension_count,
  MAX(width) AS max_width,
  MAX(height) AS max_height,
  GROUP_CONCAT(DISTINCT COALESCE(bitmap_storage_type, 'unknown')) AS storage_types,
  process_identity
FROM bitmap_rows
GROUP BY upid, process_name, process_identity
ORDER BY total_bytes DESC
LIMIT 30
