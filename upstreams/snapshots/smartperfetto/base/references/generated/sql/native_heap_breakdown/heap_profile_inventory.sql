-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/native_heap_breakdown.skill.yaml
-- Source SHA-256: c60782edef05f79ebd9a79e7f0f8f3f2dfec35cd35c839c661f0f34a68681fff
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
-- heapprofd stats are indexed by pid, except heapprofd_malformed_packet
-- which the importer indexes by upid; unindexed stats apply to all.
issue_stats AS (
  SELECT s.name, s.value,
    IIF(s.name = 'heapprofd_malformed_packet', s.idx, NULL) AS upid,
    IIF(s.name = 'heapprofd_malformed_packet', NULL, s.idx) AS pid
  FROM stats AS s
  WHERE s.name GLOB 'heapprofd*'
    AND s.severity IN ('error', 'data_loss')
    AND s.value > 0
)
SELECT
  p.upid,
  t.process_name,
  p.heap_name,
  CASE
    WHEN p.heap_name = 'com.android.art' THEN 'java_allocations_only'
    WHEN p.free_records > 0 THEN 'allocations_and_frees'
    ELSE 'no_frees_observed'
  END AS heap_semantics,
  ROUND(p.alloc_bytes / 1048576.0, 2) AS alloc_mb,
  -- Heaps without recorded frees have no measurable unreleased bytes.
  IIF(p.retention_measurable, ROUND(p.unreleased_bytes / 1048576.0, 2), NULL) AS unreleased_mb,
  p.alloc_count,
  IIF(p.retention_measurable, p.unreleased_count, NULL) AS unreleased_count,
  CASE
    WHEN p.retention_measurable THEN 'retention_measurable'
    WHEN p.heap_name = 'com.android.art' THEN 'churn_only_frees_not_recorded'
    ELSE 'churn_only_no_frees_observed'
  END AS retention_claim,
  COALESCE((
    SELECT GROUP_CONCAT(i.name || '=' || i.value, ', ')
    FROM issue_stats AS i
    WHERE i.upid = p.upid
      OR i.pid = (SELECT pid FROM process WHERE process.upid = p.upid)
      OR (i.upid IS NULL AND i.pid IS NULL)
  ), 'none') AS heapprofd_issues,
  t.process_identity,
  'heap_profile_available' AS status
FROM heap_profiles AS p
JOIN heap_target_process AS t USING (upid)
UNION ALL
SELECT
  NULL,
  NULL,
  NULL,
  NULL,
  0,
  0,
  0,
  0,
  'not_applicable',
  COALESCE((SELECT GROUP_CONCAT(name || '=' || value, ', ') FROM issue_stats), 'none'),
  'none',
  IIF(EXISTS (SELECT 1 FROM heap_profile_allocation),
    'no_heap_profile_for_requested_process', 'no_heap_profile_data')
WHERE NOT EXISTS (SELECT 1 FROM heap_profiles)
