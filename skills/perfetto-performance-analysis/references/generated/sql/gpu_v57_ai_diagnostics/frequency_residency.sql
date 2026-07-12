-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: ac78ea2ed81bd2cff026d28c2ff54159ddd20e792fccc6cbd00171f1b18c6a36
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

CREATE OR REPLACE PERFETTO TABLE __sp_v57_gpu_freq AS
SELECT
  f.id,
  f.ts,
  f.dur,
  f.value AS freq_khz,
  gct.ugpu
FROM counter_leading_intervals!((
    SELECT c.id, c.ts, c.track_id, c.value
    FROM counter AS c
    JOIN gpu_counter_track AS gct
      ON gct.id = c.track_id
    WHERE gct.name = 'gpufreq'
      AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
      AND (${end_ts} IS NULL OR c.ts < ${end_ts})
      AND (${ugpu} IS NULL OR gct.ugpu = ${ugpu})
  )) AS f
JOIN gpu_counter_track AS gct
  ON gct.id = f.track_id;

CREATE OR REPLACE PERFETTO TABLE __sp_v57_busy_at_freq AS
SELECT b.ugpu, f.freq_khz, ii.dur
FROM _interval_intersect!((__sp_v57_gpu_busy, __sp_v57_gpu_freq), (ugpu)) AS ii
JOIN __sp_v57_gpu_busy AS b
  ON b.id = ii.id_0
JOIN __sp_v57_gpu_freq AS f
  ON f.id = ii.id_1;

CREATE OR REPLACE PERFETTO TABLE __sp_v57_gpu_span AS
SELECT
  ugpu,
  MIN(ts) AS span_start,
  MAX(ts + dur) AS span_end,
  SUM(dur) AS busy_ns
FROM __sp_v57_gpu_busy
GROUP BY ugpu;

SELECT
  s.ugpu AS gpu,
  IFNULL(g.name, 'GPU ' || s.ugpu) AS gpu_name,
  s.span_end - s.span_start AS active_span_ns,
  s.busy_ns AS gpu_busy_ns,
  ROUND(100.0 * s.busy_ns / NULLIF(s.span_end - s.span_start, 0), 1) AS busy_pct_of_active,
  (SELECT MAX(freq_khz) FROM __sp_v57_gpu_freq WHERE ugpu = s.ugpu) / 1000 AS fmax_mhz,
  ROUND(
    (SELECT SUM(dur * freq_khz) FROM __sp_v57_busy_at_freq WHERE ugpu = s.ugpu) * 1.0
    / NULLIF((SELECT SUM(dur) FROM __sp_v57_busy_at_freq WHERE ugpu = s.ugpu), 0)
    / 1000,
    0
  ) AS mean_busy_mhz,
  ROUND(
    100.0 * (SELECT SUM(dur * freq_khz) FROM __sp_v57_busy_at_freq WHERE ugpu = s.ugpu)
    / NULLIF((s.span_end - s.span_start) * (SELECT MAX(freq_khz) FROM __sp_v57_gpu_freq WHERE ugpu = s.ugpu), 0),
    1
  ) AS eff_occupancy_pct,
  ROUND(
    100.0 * (SELECT SUM(dur) FROM __sp_v57_busy_at_freq WHERE ugpu = s.ugpu)
    / NULLIF(s.busy_ns, 0),
    1
  ) AS freq_coverage_pct
FROM __sp_v57_gpu_span AS s
LEFT JOIN gpu AS g
  ON g.ugpu = s.ugpu
WHERE EXISTS (SELECT 1 FROM __sp_v57_gpu_freq WHERE ugpu = s.ugpu)
ORDER BY s.ugpu
