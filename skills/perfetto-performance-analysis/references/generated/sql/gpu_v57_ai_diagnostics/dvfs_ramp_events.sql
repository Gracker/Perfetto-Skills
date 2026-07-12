-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: ac78ea2ed81bd2cff026d28c2ff54159ddd20e792fccc6cbd00171f1b18c6a36
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

CREATE OR REPLACE PERFETTO TABLE __sp_v57_gpu_params AS
SELECT
  COALESCE(${target_freq_ratio|0.9}, 0.9) AS target_ratio,
  MIN(MAX(COALESCE(${max_rows|20}, 20), 1), 200) AS max_rows;

CREATE OR REPLACE PERFETTO TABLE __sp_v57_gpu_fmax AS
SELECT ugpu, MAX(freq_khz) AS fmax_khz
FROM __sp_v57_gpu_freq
GROUP BY ugpu;

CREATE OR REPLACE PERFETTO TABLE __sp_v57_gpu_edges AS
SELECT
  b.ugpu,
  b.ts AS edge_ts,
  b.te AS busy_end,
  b.ts - LAG(b.te) OVER (PARTITION BY b.ugpu ORDER BY b.ts) AS idle_gap_ns,
  (
    SELECT f.freq_khz
    FROM __sp_v57_gpu_freq AS f
    WHERE f.ugpu = b.ugpu
      AND f.ts <= b.ts
      AND f.ts + f.dur > b.ts
  ) AS freq_at_edge_khz,
  (SELECT fmax_khz FROM __sp_v57_gpu_fmax WHERE ugpu = b.ugpu) AS fmax_khz
FROM __sp_v57_gpu_busy AS b;

SELECT
  e.ugpu AS gpu,
  IFNULL(g.name, 'GPU ' || e.ugpu) AS gpu_name,
  e.edge_ts - trace_start() AS edge_rel_ns,
  e.idle_gap_ns,
  e.freq_at_edge_khz / 1000 AS freq_at_edge_mhz,
  CAST((SELECT target_ratio FROM __sp_v57_gpu_params) * e.fmax_khz AS INT) / 1000 AS target_mhz,
  IFNULL(
    (
      SELECT MIN(f.ts)
      FROM __sp_v57_gpu_freq AS f
      WHERE f.ugpu = e.ugpu
        AND f.freq_khz >= (SELECT target_ratio FROM __sp_v57_gpu_params) * e.fmax_khz
        AND f.ts >= e.edge_ts
        AND f.ts < e.busy_end
    ),
    e.busy_end
  ) - e.edge_ts AS ramp_ns,
  CASE
    WHEN (
      SELECT MIN(f.ts)
      FROM __sp_v57_gpu_freq AS f
      WHERE f.ugpu = e.ugpu
        AND f.freq_khz >= (SELECT target_ratio FROM __sp_v57_gpu_params) * e.fmax_khz
        AND f.ts >= e.edge_ts
        AND f.ts < e.busy_end
    ) IS NOT NULL THEN 1
    ELSE 0
  END AS completed
FROM __sp_v57_gpu_edges AS e
LEFT JOIN gpu AS g
  ON g.ugpu = e.ugpu
WHERE e.freq_at_edge_khz < (SELECT target_ratio FROM __sp_v57_gpu_params) * e.fmax_khz
ORDER BY ramp_ns DESC
LIMIT (SELECT max_rows FROM __sp_v57_gpu_params)
