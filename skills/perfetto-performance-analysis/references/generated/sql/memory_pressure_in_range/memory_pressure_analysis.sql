-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/memory_pressure_in_range.skill.yaml
-- Source SHA-256: 64e35396d604190f06c52c86371844406e7049fc72ae0392d479dd05a6aa417b
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

-- Memory Pressure Analysis
--
-- Analyzes multiple sources of memory pressure:
-- 1. PSI (Pressure Stall Information) - if available
-- 2. kswapd page scanning/reclaim
-- 3. Direct reclaim events
-- 4. Compaction activity
-- 5. LMK (Low Memory Killer) events

WITH params AS (
  SELECT
    ${start_ts} AS start_ts,
    ${end_ts} AS end_ts,
    '${package}' AS package_filter
),

-- PSI Memory Pressure (if available in trace)
psi_memory AS (
  SELECT
    'psi_memory' AS source,
    c.ts,
    c.value,
    t.name AS metric_name
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  CROSS JOIN params p
  WHERE (t.name LIKE 'mem.%psi%' OR t.name LIKE '%memory_pressure%')
    AND c.ts >= p.start_ts
    AND c.ts <= p.end_ts
),

psi_summary AS (
  SELECT
    MAX(value) AS max_psi_value,
    AVG(value) AS avg_psi_value,
    COUNT(*) AS psi_sample_count
  FROM psi_memory
),

-- kswapd activity (page reclaim daemon)
kswapd_slices AS (
  SELECT
    s.ts,
    s.dur,
    s.name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  CROSS JOIN params p
  WHERE t.name LIKE 'kswapd%'
    AND s.ts >= p.start_ts
    AND s.ts <= p.end_ts
    AND s.dur > 0
),

kswapd_summary AS (
  SELECT
    COUNT(*) AS kswapd_event_count,
    COALESCE(SUM(dur), 0) AS kswapd_total_dur_ns,
    COALESCE(MAX(dur), 0) AS kswapd_max_dur_ns,
    COALESCE(AVG(dur), 0) AS kswapd_avg_dur_ns
  FROM kswapd_slices
),

-- Direct reclaim events (synchronous memory allocation stalls)
direct_reclaim AS (
  SELECT
    s.ts,
    s.dur,
    s.name,
    t.name AS thread_name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  CROSS JOIN params p
  WHERE (s.name LIKE '%direct_reclaim%' OR s.name LIKE '%reclaim%alloc%')
    AND s.ts >= p.start_ts
    AND s.ts <= p.end_ts
),

direct_reclaim_summary AS (
  SELECT
    COUNT(*) AS direct_reclaim_count,
    COALESCE(SUM(dur), 0) AS direct_reclaim_total_ns,
    COALESCE(MAX(dur), 0) AS direct_reclaim_max_ns
  FROM direct_reclaim
),

-- Memory compaction events
compaction_events AS (
  SELECT
    s.ts,
    s.dur,
    s.name
  FROM slice s
  CROSS JOIN params p
  WHERE s.name LIKE '%compact%'
    AND s.ts >= p.start_ts
    AND s.ts <= p.end_ts
),

compaction_summary AS (
  SELECT
    COUNT(*) AS compaction_count,
    COALESCE(SUM(dur), 0) AS compaction_total_ns
  FROM compaction_events
),

-- LMK (Low Memory Killer) events
lmk_events AS (
  SELECT
    ts,
    dur,
    name
  FROM slice
  CROSS JOIN params p
  WHERE (name LIKE '%lowmemory%' OR name LIKE '%lmkd%' OR name LIKE '%oom_adj%')
    AND ts >= p.start_ts
    AND ts <= p.end_ts
),

lmk_summary AS (
  SELECT
    COUNT(*) AS lmk_event_count,
    COALESCE(SUM(dur), 0) AS lmk_total_ns
  FROM lmk_events
),

-- Memory allocation stalls (blocked allocations)
alloc_stalls AS (
  SELECT
    s.ts,
    s.dur,
    s.name,
    t.name AS thread_name,
    p2.name AS process_name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p2 ON t.upid = p2.upid
  CROSS JOIN params p
  WHERE (s.name LIKE '%alloc_pages%' OR s.name LIKE '%page_alloc%')
    AND s.dur > 1000000  -- > 1ms stall
    AND s.ts >= p.start_ts
    AND s.ts <= p.end_ts
),

alloc_stall_summary AS (
  SELECT
    COUNT(*) AS alloc_stall_count,
    COALESCE(SUM(dur), 0) AS alloc_stall_total_ns,
    COALESCE(MAX(dur), 0) AS alloc_stall_max_ns
  FROM alloc_stalls
),

-- Page cache activity (mm_filemap_add_to_page_cache = cache miss → disk read)
page_cache_adds AS (
  SELECT COUNT(*) AS add_count
  FROM raw r
  CROSS JOIN params p
  WHERE r.name = 'mm_filemap_add_to_page_cache'
    AND r.ts >= p.start_ts
    AND r.ts <= p.end_ts
),

-- Page cache evictions (mm_filemap_delete_from_page_cache = page evicted)
page_cache_deletes AS (
  SELECT COUNT(*) AS delete_count
  FROM raw r
  CROSS JOIN params p
  WHERE r.name = 'mm_filemap_delete_from_page_cache'
    AND r.ts >= p.start_ts
    AND r.ts <= p.end_ts
),

-- Calculate overall pressure score
pressure_score AS (
  SELECT
    -- Weight factors for different pressure indicators
    CASE
      WHEN (SELECT kswapd_event_count FROM kswapd_summary) > 10 THEN 30
      WHEN (SELECT kswapd_event_count FROM kswapd_summary) > 3 THEN 15
      WHEN (SELECT kswapd_event_count FROM kswapd_summary) > 0 THEN 5
      ELSE 0
    END +
    CASE
      WHEN (SELECT direct_reclaim_count FROM direct_reclaim_summary) > 5 THEN 40
      WHEN (SELECT direct_reclaim_count FROM direct_reclaim_summary) > 1 THEN 20
      WHEN (SELECT direct_reclaim_count FROM direct_reclaim_summary) > 0 THEN 10
      ELSE 0
    END +
    CASE
      WHEN (SELECT lmk_event_count FROM lmk_summary) > 0 THEN 30
      ELSE 0
    END +
    CASE
      WHEN (SELECT alloc_stall_count FROM alloc_stall_summary) > 3 THEN 20
      WHEN (SELECT alloc_stall_count FROM alloc_stall_summary) > 0 THEN 10
      ELSE 0
    END +
    CASE
      WHEN (SELECT delete_count FROM page_cache_deletes) > 100 THEN 15
      WHEN (SELECT delete_count FROM page_cache_deletes) > 10 THEN 5
      ELSE 0
    END AS score
)

SELECT
  -- kswapd metrics
  (SELECT kswapd_event_count FROM kswapd_summary) AS kswapd_events,
  ROUND((SELECT kswapd_total_dur_ns FROM kswapd_summary) / 1000000.0, 2) AS kswapd_total_ms,
  ROUND((SELECT kswapd_max_dur_ns FROM kswapd_summary) / 1000000.0, 2) AS kswapd_max_ms,

  -- Direct reclaim metrics
  (SELECT direct_reclaim_count FROM direct_reclaim_summary) AS direct_reclaim_events,
  ROUND((SELECT direct_reclaim_total_ns FROM direct_reclaim_summary) / 1000000.0, 2) AS direct_reclaim_total_ms,
  ROUND((SELECT direct_reclaim_max_ns FROM direct_reclaim_summary) / 1000000.0, 2) AS direct_reclaim_max_ms,

  -- Compaction metrics
  (SELECT compaction_count FROM compaction_summary) AS compaction_events,
  ROUND((SELECT compaction_total_ns FROM compaction_summary) / 1000000.0, 2) AS compaction_total_ms,

  -- LMK metrics
  (SELECT lmk_event_count FROM lmk_summary) AS lmk_events,

  -- Allocation stall metrics
  (SELECT alloc_stall_count FROM alloc_stall_summary) AS alloc_stall_events,
  ROUND((SELECT alloc_stall_max_ns FROM alloc_stall_summary) / 1000000.0, 2) AS alloc_stall_max_ms,

  -- Page cache activity
  (SELECT add_count FROM page_cache_adds) AS page_cache_add_events,
  (SELECT delete_count FROM page_cache_deletes) AS page_cache_delete_events,

  -- PSI metrics (if available)
  (SELECT max_psi_value FROM psi_summary) AS psi_max,
  (SELECT avg_psi_value FROM psi_summary) AS psi_avg,

  -- Overall pressure assessment
  (SELECT score FROM pressure_score) AS pressure_score,
  CASE
    WHEN (SELECT score FROM pressure_score) >= 70 THEN 'critical'
    WHEN (SELECT score FROM pressure_score) >= 40 THEN 'high'
    WHEN (SELECT score FROM pressure_score) >= 15 THEN 'moderate'
    WHEN (SELECT score FROM pressure_score) > 0 THEN 'low'
    ELSE 'none'
  END AS pressure_level,

  -- Time range info
  (SELECT end_ts - start_ts FROM params) / 1000000.0 AS range_duration_ms
