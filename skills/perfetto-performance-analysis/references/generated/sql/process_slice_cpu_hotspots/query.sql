-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/process_slice_cpu_hotspots.skill.yaml
-- Source SHA-256: fd6bc72d2cee67b783f9795e253586db60f2b7a3c3e786495b6d998e69403a8a
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH
raw_input AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS raw_start_ts,
    COALESCE(${end_ts}, trace_end()) AS raw_end_ts,
    ${upid} AS target_upid,
    NULLIF(COALESCE(NULLIF('${process_name|}', ''), NULLIF('${package|}', '')), '') AS target_process,
    NULLIF('${slice_name|}', '') AS target_slice,
    CASE
      WHEN '${thread_scope|all}' IN ('all', 'main', 'render', 'main_render') THEN '${thread_scope|all}'
      ELSE 'all'
    END AS thread_scope,
    MAX(COALESCE(${min_cpu_ns|0}, 0), 0) AS min_cpu_ns,
    MIN(MAX(COALESCE(${top_k|10}, 10), 1), 100) AS top_k
),
input AS (
  SELECT
    MIN(raw_start_ts, raw_end_ts) AS start_ts,
    MAX(raw_start_ts, raw_end_ts) AS end_ts,
    target_upid,
    target_process,
    target_slice,
    thread_scope,
    min_cpu_ns,
    top_k
  FROM raw_input
),
target_threads AS (
  SELECT
    p.upid,
    p.pid,
    p.name AS process_name,
    t.utid,
    t.tid,
    COALESCE(t.name, '') AS thread_name
  FROM process p
  JOIN thread t ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (
      (
        i.target_upid IS NOT NULL
        AND p.upid = i.target_upid
      )
      OR (
        i.target_upid IS NULL
        AND (
          i.target_process IS NULL
          OR p.name GLOB i.target_process || '*'
          OR p.name LIKE '%' || i.target_process || '%'
        )
      )
    )
    AND (
      i.thread_scope = 'all'
      OR (
        i.thread_scope IN ('main', 'main_render')
        AND (t.is_main_thread = 1 OR t.tid = p.pid)
      )
      OR (
        i.thread_scope IN ('render', 'main_render')
        AND (
          t.name = 'RenderThread'
          OR t.name = 'GPU completion'
          OR t.name GLOB '[0-9]*.ui'
          OR t.name GLOB '[0-9]*.raster'
        )
      )
    )
),
candidate_slices AS (
  SELECT
    s.id,
    s.name AS slice_name,
    s.ts,
    s.dur,
    tt.upid,
    tt.process_name,
    tt.utid,
    tt.thread_name
  FROM slice s
  JOIN thread_track track ON s.track_id = track.id
  JOIN target_threads tt ON track.utid = tt.utid
  CROSS JOIN input i
  WHERE s.dur > 0
    AND s.ts < i.end_ts
    AND s.ts + s.dur > i.start_ts
    AND (
      i.target_slice IS NULL
      OR (
        INSTR(i.target_slice, '%') > 0
        AND s.name LIKE i.target_slice
      )
      OR (
        INSTR(i.target_slice, '%') = 0
        AND INSTR(s.name, i.target_slice) > 0
      )
    )
),
per_slice_cpu AS (
  SELECT
    cs.id,
    cs.process_name,
    cs.slice_name,
    cs.utid,
    cs.thread_name,
    MAX(cs.ts, i.start_ts) AS clipped_start_ts,
    MIN(cs.ts + cs.dur, i.end_ts) AS clipped_end_ts,
    MIN(cs.ts + cs.dur, i.end_ts) - MAX(cs.ts, i.start_ts) AS wall_ns,
    COALESCE(SUM(
      MIN(MIN(cs.ts + cs.dur, i.end_ts), ts.ts + ts.dur)
      - MAX(MAX(cs.ts, i.start_ts), ts.ts)
    ), 0) AS cpu_ns
  FROM candidate_slices cs
  CROSS JOIN input i
  LEFT JOIN thread_state ts ON ts.utid = cs.utid
    AND ts.state = 'Running'
    AND ts.dur > 0
    AND ts.ts < MIN(cs.ts + cs.dur, i.end_ts)
    AND ts.ts + ts.dur > MAX(cs.ts, i.start_ts)
  GROUP BY
    cs.id,
    cs.process_name,
    cs.slice_name,
    cs.utid,
    cs.thread_name,
    cs.ts,
    cs.dur,
    i.start_ts,
    i.end_ts
),
aggregate_cpu AS (
  SELECT
    process_name,
    slice_name,
    COUNT(*) AS count,
    COUNT(DISTINCT utid) AS thread_count,
    SUBSTR(GROUP_CONCAT(DISTINCT COALESCE(NULLIF(thread_name, ''), '<unnamed>')), 1, 240) AS sample_threads,
    SUM(cpu_ns) AS total_cpu_ns,
    SUM(wall_ns) AS total_wall_ns,
    AVG(cpu_ns) AS avg_cpu_ns,
    MAX(cpu_ns) AS max_cpu_ns,
    MIN(clipped_start_ts) AS first_ts,
    MAX(clipped_end_ts) AS last_ts
  FROM per_slice_cpu
  GROUP BY process_name, slice_name
  HAVING SUM(cpu_ns) >= (SELECT min_cpu_ns FROM input)
),
selected_total AS (
  SELECT SUM(total_cpu_ns) AS total_cpu_ns
  FROM aggregate_cpu
)
SELECT
  process_name,
  slice_name,
  count,
  thread_count,
  sample_threads,
  ROUND(total_cpu_ns / 1e6, 2) AS total_cpu_ms,
  ROUND(total_wall_ns / 1e6, 2) AS total_wall_ms,
  ROUND(avg_cpu_ns / 1e6, 2) AS avg_cpu_ms,
  ROUND(max_cpu_ns / 1e6, 2) AS max_cpu_ms,
  ROUND(100.0 * total_cpu_ns / NULLIF(total_wall_ns, 0), 1) AS cpu_efficiency_pct,
  ROUND(100.0 * total_cpu_ns / NULLIF((SELECT total_cpu_ns FROM selected_total), 0), 1) AS selected_cpu_share_pct,
  printf('%d', first_ts) AS first_ts,
  printf('%d', last_ts) AS last_ts
FROM aggregate_cpu
WHERE total_cpu_ns > 0
ORDER BY total_cpu_ns DESC
LIMIT (SELECT top_k FROM input)
