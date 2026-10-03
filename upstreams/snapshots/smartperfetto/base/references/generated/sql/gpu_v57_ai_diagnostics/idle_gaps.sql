-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: 608783942f2db1a99117105e5d2d95faddd0b3074bd5cfdc5ad464f383ec5280

WITH input AS (
  SELECT MIN(MAX(COALESCE(${max_rows|20}, 20), 1), 200) AS max_rows
),
gaps AS (
  SELECT
    ugpu,
    te AS gap_start_ts,
    LEAD(ts) OVER (PARTITION BY ugpu ORDER BY ts) AS next_ts
  FROM __sp_v57_gpu_busy
)
SELECT
  gaps.ugpu AS gpu,
  IFNULL(g.name, 'GPU ' || gaps.ugpu) AS gpu_name,
  gaps.gap_start_ts - trace_start() AS gap_start_rel_ns,
  gaps.next_ts - gaps.gap_start_ts AS gap_dur_ns
FROM gaps
LEFT JOIN gpu AS g
  ON g.ugpu = gaps.ugpu
WHERE gaps.next_ts - gaps.gap_start_ts > 0
ORDER BY gap_dur_ns DESC
LIMIT (SELECT max_rows FROM input)
