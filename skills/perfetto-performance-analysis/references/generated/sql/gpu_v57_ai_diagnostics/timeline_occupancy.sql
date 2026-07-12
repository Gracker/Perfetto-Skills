-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: ac78ea2ed81bd2cff026d28c2ff54159ddd20e792fccc6cbd00171f1b18c6a36
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

CREATE OR REPLACE PERFETTO TABLE __sp_v57_gpu_work AS
SELECT
  s.ts,
  s.dur,
  IFNULL(EXTRACT_ARG(t.dimension_arg_set_id, 'ugpu'), 0) AS ugpu
FROM gpu_slice AS s
JOIN gpu_track AS t
  ON s.track_id = t.id
WHERE s.dur > 0
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  AND (${ugpu} IS NULL OR IFNULL(EXTRACT_ARG(t.dimension_arg_set_id, 'ugpu'), 0) = ${ugpu});

CREATE OR REPLACE PERFETTO TABLE __sp_v57_gpu_busy AS
SELECT
  ROW_NUMBER() OVER (ORDER BY ugpu, ts) AS id,
  ugpu,
  ts,
  dur,
  ts + dur AS te
FROM interval_merge_overlapping_partitioned!((
    SELECT ts, dur, ugpu FROM __sp_v57_gpu_work
  ), (ugpu));

SELECT
  k.ugpu AS gpu,
  IFNULL(g.name, 'GPU ' || k.ugpu) AS gpu_name,
  COUNT(*) AS activities,
  trace_end() - trace_start() AS trace_wall_ns,
  MAX(k.ts + k.dur) - MIN(k.ts) AS active_span_ns,
  (SELECT SUM(b.dur) FROM __sp_v57_gpu_busy AS b WHERE b.ugpu = k.ugpu) AS gpu_busy_ns,
  ROUND(
    100.0 * (SELECT SUM(b.dur) FROM __sp_v57_gpu_busy AS b WHERE b.ugpu = k.ugpu)
    / NULLIF(MAX(k.ts + k.dur) - MIN(k.ts), 0),
    1
  ) AS busy_pct_of_active,
  ROUND(
    100.0 * (SELECT SUM(b.dur) FROM __sp_v57_gpu_busy AS b WHERE b.ugpu = k.ugpu)
    / NULLIF(trace_end() - trace_start(), 0),
    1
  ) AS busy_pct_of_trace
FROM __sp_v57_gpu_work AS k
LEFT JOIN gpu AS g
  ON g.ugpu = k.ugpu
GROUP BY k.ugpu, gpu_name
ORDER BY k.ugpu
