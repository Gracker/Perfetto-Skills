-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: ac78ea2ed81bd2cff026d28c2ff54159ddd20e792fccc6cbd00171f1b18c6a36
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

CREATE OR REPLACE PERFETTO TABLE __sp_v57_gpu_params AS
SELECT
  COALESCE(${target_freq_ratio|0.9}, 0.9) AS target_ratio,
  MIN(MAX(COALESCE(${min_throttle_ns|1000}, 1000), 1), 10000000000) AS min_throttle_ns,
  MIN(MAX(COALESCE(${max_rows|20}, 20), 1), 200) AS max_rows;

CREATE OR REPLACE PERFETTO TABLE __sp_v57_gpu_low_busy AS
SELECT ii.ts, ii.dur, f.freq_khz, b.ugpu
FROM _interval_intersect!((__sp_v57_gpu_busy, __sp_v57_gpu_freq), (ugpu)) AS ii
JOIN __sp_v57_gpu_busy AS b
  ON b.id = ii.id_0
JOIN __sp_v57_gpu_freq AS f
  ON f.id = ii.id_1
WHERE f.freq_khz < (SELECT target_ratio FROM __sp_v57_gpu_params) * (SELECT fmax_khz FROM __sp_v57_gpu_fmax WHERE ugpu = b.ugpu);

SELECT
  l.ugpu AS gpu,
  IFNULL(g.name, 'GPU ' || l.ugpu) AS gpu_name,
  l.ts - trace_start() AS start_rel_ns,
  l.dur AS dur_ns,
  l.freq_khz / 1000 AS freq_mhz,
  CAST((SELECT target_ratio FROM __sp_v57_gpu_params) * (SELECT fmax_khz FROM __sp_v57_gpu_fmax WHERE ugpu = l.ugpu) AS INT) / 1000 AS target_mhz,
  (
    SELECT ROUND(AVG(c.value), 1)
    FROM counter AS c
    JOIN gpu_counter_track AS t
      ON t.id = c.track_id
    WHERE t.name = 'Temperature'
      AND t.ugpu = l.ugpu
      AND c.ts >= l.ts
      AND c.ts < l.ts + l.dur
  ) AS temp_c,
  (
    SELECT ROUND(AVG(c.value), 1)
    FROM counter AS c
    JOIN gpu_counter_track AS t
      ON t.id = c.track_id
    WHERE t.name = 'Power'
      AND t.ugpu = l.ugpu
      AND c.ts >= l.ts
      AND c.ts < l.ts + l.dur
  ) AS power_w
FROM __sp_v57_gpu_low_busy AS l
LEFT JOIN gpu AS g
  ON g.ugpu = l.ugpu
WHERE l.dur >= (SELECT min_throttle_ns FROM __sp_v57_gpu_params)
  AND l.ts >= (
    SELECT MAX(e.ramp_reach_ts)
    FROM (
      SELECT
        b.ugpu,
        b.ts AS edge_ts,
        (
          SELECT MIN(f.ts)
          FROM __sp_v57_gpu_freq AS f
          WHERE f.ugpu = b.ugpu
            AND f.freq_khz >= (SELECT target_ratio FROM __sp_v57_gpu_params) * (SELECT fmax_khz FROM __sp_v57_gpu_fmax WHERE ugpu = b.ugpu)
            AND f.ts >= b.ts
            AND f.ts < b.te
        ) AS ramp_reach_ts
      FROM __sp_v57_gpu_busy AS b
    ) AS e
    WHERE e.ugpu = l.ugpu
      AND e.edge_ts <= l.ts
      AND e.ramp_reach_ts IS NOT NULL
  )
ORDER BY l.dur DESC
LIMIT (SELECT max_rows FROM __sp_v57_gpu_params)
