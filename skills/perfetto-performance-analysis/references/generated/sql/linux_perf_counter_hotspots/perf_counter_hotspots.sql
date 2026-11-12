-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/linux_perf_counter_hotspots.skill.yaml
-- Source SHA-256: c86639e8f7f1629839d6b73bc1369754c96e74ca1f44c2557f44df90717faf82

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Input: the step parameter end_ts; requires the linux.perf.counters module.
-- One row per linux.perf sample counter value: the number of counter events
-- since the previous sample on the same counter track. linux.perf hardware
-- counters (cpu-cycles, instructions, cache-*) are cumulative per
-- (perf session, CPU) track, so only this delta is a count of events; it is
-- attributed to the sampled thread, the perf report period weighting. The
-- first sample of each track has no delta and is dropped, as is a negative
-- delta (counter reset). Samples after end_ts are cut before LAG, which only
-- looks back; the lower window bound must be applied by the consumer after
-- this CTE so the first in-window sample keeps its delta. Process/thread
-- filters also belong to the consumer: a per-CPU track interleaves threads.
linux_perf_counter_deltas AS (
  SELECT ts, utid, track_id, delta
  FROM (
    SELECT
      l.ts,
      l.utid,
      l.track_id,
      l.counter_value - LAG(l.counter_value) OVER (PARTITION BY l.track_id ORDER BY l.ts) AS delta
    FROM linux_perf_sample_with_counters l
    WHERE ${end_ts} IS NULL OR l.ts < ${end_ts}
  )
  WHERE delta >= 0
)
,
input AS (
  SELECT
    COALESCE(${__process_scope.upid}, ${upid}) AS target_upid,
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${start_ts}, 0) AS start_ts
)
SELECT
  COALESCE(tr.name, printf('counter:%d', d.track_id)) AS counter_name,
  COALESCE(p.name, '<kernel/unknown>') AS process_name,
  COALESCE(t.name, printf('utid:%d', d.utid)) AS thread_name,
  COUNT(*) AS sample_count,
  ROUND(SUM(d.delta), 0) AS total_counter_delta,
  ROUND(AVG(d.delta), 2) AS avg_counter_delta
FROM linux_perf_counter_deltas d
LEFT JOIN thread t ON d.utid = t.utid
LEFT JOIN process p ON t.upid = p.upid
LEFT JOIN track tr ON d.track_id = tr.id
CROSS JOIN input i
WHERE d.ts >= i.start_ts
  AND (
    (i.target_upid IS NOT NULL AND p.upid = i.target_upid)
    OR (i.target_upid IS NULL AND (i.target_process = '' OR p.name = i.target_process OR p.name GLOB i.target_process || ':*'))
  )
GROUP BY counter_name, process_name, thread_name
ORDER BY total_counter_delta DESC, sample_count DESC
LIMIT 100
