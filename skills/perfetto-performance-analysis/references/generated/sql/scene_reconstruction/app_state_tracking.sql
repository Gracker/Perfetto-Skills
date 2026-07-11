-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH oom_changes AS (
  SELECT
    c.ts,
    p.name AS app_package,
    CAST(c.value AS INT) AS oom_adj,
    LAG(CAST(c.value AS INT)) OVER (PARTITION BY p.name ORDER BY c.ts) AS prev_oom_adj
  FROM counter c
  JOIN process_counter_track pct ON c.track_id = pct.id
  JOIN process p ON pct.upid = p.upid
  WHERE pct.name = 'oom_score_adj'
    AND p.name IS NOT NULL
    AND p.name != ''
    AND p.name NOT LIKE '%system_server%'
    AND p.name NOT LIKE '%surfaceflinger%'
    AND p.name NOT LIKE '%servicemanager%'
    AND p.name NOT LIKE '%zygote%'
    AND p.name NOT LIKE '%init%'
    AND p.name NOT LIKE '%logd%'
    AND p.name NOT LIKE '%vold%'
    AND p.name NOT LIKE '%lmkd%'
),
-- Filter to only significant transitions (foreground/visible/background boundaries)
significant_changes AS (
  SELECT
    ts, app_package, oom_adj, prev_oom_adj,
    CASE
      WHEN oom_adj <= 0 THEN '前台'
      WHEN oom_adj <= 200 THEN '可见'
      WHEN oom_adj <= 700 THEN '后台'
      ELSE '缓存/即将回收'
    END AS state_label,
    CASE
      WHEN prev_oom_adj IS NULL THEN '进程出现'
      WHEN prev_oom_adj > 0 AND oom_adj <= 0 THEN '进入前台'
      WHEN prev_oom_adj <= 0 AND oom_adj > 0 THEN '离开前台'
      WHEN prev_oom_adj <= 200 AND oom_adj > 200 THEN '进入后台'
      WHEN prev_oom_adj > 700 AND oom_adj <= 200 THEN '恢复可见'
      ELSE NULL
    END AS transition
  FROM oom_changes
  WHERE prev_oom_adj IS NULL
    OR (prev_oom_adj > 0 AND oom_adj <= 0)
    OR (prev_oom_adj <= 0 AND oom_adj > 0)
    OR (prev_oom_adj <= 200 AND oom_adj > 200)
    OR (prev_oom_adj > 700 AND oom_adj <= 200)
),
-- Process start events (from process table start_ts)
proc_starts AS (
  SELECT
    p.start_ts AS ts,
    p.name AS app_package,
    -1000 AS oom_adj,
    '进程创建' AS state_label,
    '进程创建' AS transition
  FROM process p
  WHERE p.start_ts IS NOT NULL
    AND p.start_ts > 0
    AND p.name IS NOT NULL
    AND p.name GLOB '*.*'
    AND p.name NOT LIKE '%system_server%'
    AND p.name NOT LIKE '%zygote%'
)
SELECT
  printf('%d', ts) AS ts,
  COALESCE(transition, state_label) AS event,
  app_package,
  oom_adj,
  state_label,
  'app_state' AS category
FROM (
  SELECT ts, app_package, oom_adj, state_label, transition
  FROM significant_changes
  WHERE transition IS NOT NULL
  UNION ALL
  SELECT ts, app_package, oom_adj, state_label, transition
  FROM proc_starts
)
ORDER BY ts
LIMIT 200
