-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 32494b794e68cb6976f27938f66c022758ebf4fcc0826baa535203c36b6aaceb
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH lmk_stats AS (
  SELECT
    COUNT(*) AS total_kills,
    MIN(oom_score_adj) AS min_oom_adj,
    ROUND(AVG(oom_score_adj), 0) AS avg_oom_adj,
    SUM(CASE WHEN oom_score_adj <= 0 THEN 1 ELSE 0 END) AS foreground_kills,
    SUM(CASE WHEN oom_score_adj <= 200 THEN 1 ELSE 0 END) AS high_priority_kills,
    SUM(CASE WHEN oom_score_adj > 900 THEN 1 ELSE 0 END) AS cached_kills,
    COUNT(DISTINCT process_name) AS distinct_processes,
    ROUND((MAX(ts) - MIN(ts)) / 1e9, 2) AS span_seconds,
    ROUND(
      COUNT(*) * 1e9 / NULLIF(MAX(ts) - MIN(ts), 0),
      2
    ) AS kills_per_second,
    SUM(CASE WHEN kill_reason IN ('LOW_SWAP_AND_THRASHING', 'LOW_MEM_AND_THRASHING', 'DIRECT_RECL_AND_THRASHING') THEN 1 ELSE 0 END) AS thrashing_kills,
    SUM(CASE WHEN kill_reason IN ('LOW_MEM', 'LOW_MEM_AND_SWAP', 'LOW_MEM_AND_SWAP_UTIL') THEN 1 ELSE 0 END) AS low_mem_kills,
    SUM(CASE WHEN kill_reason = 'PRESSURE_AFTER_KILL' THEN 1 ELSE 0 END) AS pressure_after_kill_count
  FROM android_lmk_events
  WHERE CASE WHEN '${package}' != ''
             THEN process_name GLOB '*${package}*'
             ELSE 1 END
    AND (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
restart_stats AS (
  SELECT
    COUNT(*) AS total_restarts,
    SUM(CASE WHEN avg_delay_ms < 1000 THEN 1 ELSE 0 END) AS fast_restart_count
  FROM (
    SELECT
      le.process_name,
      AVG((MIN(p.start_ts) - le.ts) / 1e6) AS avg_delay_ms
    FROM android_lmk_events le
    JOIN process p ON p.name GLOB le.process_name || '*' AND p.start_ts > le.ts
    WHERE CASE WHEN '${package}' != ''
               THEN le.process_name GLOB '*${package}*'
               ELSE 1 END
      AND (${start_ts} IS NULL OR le.ts > ${start_ts})
      AND (${end_ts} IS NULL OR le.ts < ${end_ts})
    GROUP BY le.process_name, le.ts
  )
)
SELECT * FROM (
  -- LMK_SEVERE: 前台/系统进程被杀
  SELECT
    'LMK_SEVERE' AS category,
    'critical' AS severity,
    '前台/系统进程被杀 (' || s.foreground_kills || ' 次, 最低 oom_adj=' || s.min_oom_adj || ')，严重影响用户体验' AS description,
    '前台进程被杀 ' || s.foreground_kills || ' 次, 高优先级被杀 ' || s.high_priority_kills || ' 次, 影响 ' || s.distinct_processes || ' 个进程' AS evidence
  FROM lmk_stats s
  WHERE s.foreground_kills > 0

  UNION ALL

  -- LMK_PRESSURE: 频繁杀进程，系统内存持续紧张
  SELECT
    'LMK_PRESSURE' AS category,
    'critical' AS severity,
    '内存持续紧张，频繁杀进程 (' || s.total_kills || ' 次, ' || COALESCE(s.kills_per_second, 0) || '/s)' AS description,
    '总杀进程 ' || s.total_kills || ' 次, 低内存触发 ' || s.low_mem_kills || ' 次, Thrashing 触发 ' || s.thrashing_kills || ' 次, PRESSURE_AFTER_KILL ' || s.pressure_after_kill_count || ' 次' AS evidence
  FROM lmk_stats s
  WHERE s.total_kills > 10 OR COALESCE(s.kills_per_second, 0) > 1

  UNION ALL

  -- LMK_THRASHING: 杀-重启循环
  SELECT
    'LMK_THRASHING' AS category,
    'warning' AS severity,
    '检测到进程杀-重启循环 (' || r.fast_restart_count || ' 次快速重启)，加剧内存压力' AS description,
    '总重启 ' || r.total_restarts || ' 次, 快速重启 (<1s) ' || r.fast_restart_count || ' 次, Thrashing 杀进程 ' || s.thrashing_kills || ' 次' AS evidence
  FROM lmk_stats s, restart_stats r
  WHERE r.fast_restart_count > 2

  UNION ALL

  -- LMK_HIGH_PRIORITY: 高优先级但非前台进程被杀
  SELECT
    'LMK_HIGH_PRIORITY' AS category,
    'warning' AS severity,
    '高优先级进程被杀 (' || s.high_priority_kills || ' 次, oom_adj <= 200)，用户可能感知' AS description,
    '高优先级被杀 ' || s.high_priority_kills || ' 次, 平均 oom_adj=' || s.avg_oom_adj || ', 影响 ' || s.distinct_processes || ' 个进程' AS evidence
  FROM lmk_stats s
  WHERE s.high_priority_kills > 0 AND s.foreground_kills = 0

  UNION ALL

  -- LMK_NORMAL: 仅缓存进程被杀，正常行为
  SELECT
    'LMK_NORMAL' AS category,
    'info' AS severity,
    'LMK 行为正常，仅杀缓存进程 (共 ' || s.total_kills || ' 次)' AS description,
    '总杀进程 ' || s.total_kills || ' 次, 缓存进程 ' || s.cached_kills || ' 次, 平均 oom_adj=' || s.avg_oom_adj AS evidence
  FROM lmk_stats s
  WHERE s.high_priority_kills = 0
    AND s.total_kills <= 10
    AND COALESCE(s.kills_per_second, 0) <= 1
)
ORDER BY CASE severity
  WHEN 'critical' THEN 1
  WHEN 'warning' THEN 2
  WHEN 'info' THEN 3
END
