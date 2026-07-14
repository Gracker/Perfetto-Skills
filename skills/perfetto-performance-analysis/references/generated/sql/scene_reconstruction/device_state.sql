-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH time_bounds AS (
  SELECT MIN(ts) AS t_start, MAX(ts) AS t_end
  FROM (
    SELECT ts FROM slice WHERE dur > 0
    UNION ALL
    SELECT ts FROM counter WHERE value IS NOT NULL
  )
),
-- CPU frequency ranges: report min/max freq per CPU cluster
cpu_freq AS (
  SELECT
    printf('%d', MIN(c.ts)) AS ts,
    'CPU ' || ct.cpu || ' 频率范围' AS event,
    CAST(CAST(MIN(c.value) / 1000 AS INT) AS TEXT) || ' - ' ||
      CAST(CAST(MAX(c.value) / 1000 AS INT) AS TEXT) || ' MHz' AS value,
    'cpu_freq' AS category
  FROM counter c
  JOIN cpu_counter_track ct ON c.track_id = ct.id
  WHERE ct.name = 'cpufreq'
  GROUP BY ct.cpu
),
-- Memory pressure (low memory killer / pressure stall)
mem_pressure AS (
  SELECT
    printf('%d', c.ts) AS ts,
    'MemPressure: ' || ct.name AS event,
    CAST(ROUND(c.value) AS TEXT) AS value,
    'memory' AS category
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name LIKE '%mem%pressure%'
    OR ct.name LIKE '%MemFree%'
    OR ct.name LIKE '%SwapFree%'
    OR ct.name = 'oom_score_adj')
    AND c.value IS NOT NULL
  ORDER BY c.ts
  LIMIT 1
),
-- Thermal zones
thermal AS (
  SELECT
    printf('%d', c.ts) AS ts,
    '温度: ' || ct.name AS event,
    CAST(ROUND(c.value / 1000.0, 1) AS TEXT) || ' °C' AS value,
    'thermal' AS category
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE ct.name LIKE '%thermal_zone%'
    AND c.value IS NOT NULL
  GROUP BY ct.name
  HAVING c.ts = MAX(c.ts)
  LIMIT 10
),
-- Battery / charging status from counter tracks
battery AS (
  SELECT
    printf('%d', c.ts) AS ts,
    CASE
      WHEN ct.name LIKE '%charge%' THEN '电池电量'
      WHEN ct.name LIKE '%plugged%' THEN '充电状态'
      WHEN ct.name LIKE '%voltage%' THEN '电池电压'
      WHEN ct.name LIKE '%current%' THEN '电池电流'
      ELSE ct.name
    END AS event,
    CASE
      WHEN ct.name LIKE '%plugged%' THEN
        CASE CAST(c.value AS INT)
          WHEN 0 THEN '未充电'
          WHEN 1 THEN 'AC 充电'
          WHEN 2 THEN 'USB 充电'
          WHEN 4 THEN '无线充电'
          ELSE '充电(' || CAST(CAST(c.value AS INT) AS TEXT) || ')'
        END
      WHEN ct.name LIKE '%charge%' AND c.value <= 100 THEN CAST(CAST(c.value AS INT) AS TEXT) || '%'
      ELSE CAST(ROUND(c.value) AS TEXT)
    END AS value,
    'battery' AS category
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name LIKE '%battery%charge%'
    OR ct.name LIKE '%battery%plugged%'
    OR ct.name LIKE 'batt.%')
    AND c.value IS NOT NULL
  GROUP BY ct.name
  HAVING c.ts = MIN(c.ts)
  ORDER BY c.ts
  LIMIT 10
),
-- Foreground apps (oom_adj <= 0)
fg_apps AS (
  SELECT
    printf('%d', c.ts) AS ts,
    '前台进程: ' || p.name AS event,
    'oom_adj=' || CAST(CAST(c.value AS INT) AS TEXT) AS value,
    'foreground_app' AS category
  FROM counter c
  JOIN process_counter_track pct ON c.track_id = pct.id
  JOIN process p ON pct.upid = p.upid
  WHERE pct.name = 'oom_score_adj'
    AND c.value <= 0
    AND p.name IS NOT NULL
    AND p.name != ''
    AND p.name NOT LIKE '%system_server%'
    AND p.name NOT LIKE '%surfaceflinger%'
    AND p.name NOT LIKE '%zygote%'
  GROUP BY p.name
  HAVING c.ts = MIN(c.ts)
  ORDER BY c.ts
  LIMIT 20
)
SELECT * FROM cpu_freq
UNION ALL SELECT * FROM mem_pressure
UNION ALL SELECT * FROM thermal
UNION ALL SELECT * FROM battery
UNION ALL SELECT * FROM fg_apps
ORDER BY ts
LIMIT 100
