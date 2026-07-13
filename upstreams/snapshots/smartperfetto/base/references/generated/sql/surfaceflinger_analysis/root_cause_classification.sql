-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 883c9e637f8166269939f7f817af9ef900c89e2215ca90cb3c0ad0d45443daad
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

WITH
-- 合成统计
sf_compositions AS (
  SELECT
    s.ts,
    s.dur,
    s.name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = 'surfaceflinger' OR p.name = '/system/bin/surfaceflinger')
    AND (s.name GLOB '*onMessageInvalidate*'
         OR s.name GLOB '*onMessageRefresh*'
         OR s.name GLOB '*composite*'
         OR s.name GLOB '*Composite*')
    AND s.dur > 0
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
),
composition_stats AS (
  SELECT
    COUNT(*) as total_count,
    AVG(dur) / 1e6 as avg_dur_ms,
    MAX(dur) / 1e6 as max_dur_ms,
    SUM(CASE WHEN dur > ${vsync_env.data[0].vsync_period_ns} * ${slow_composition_multiplier|1.5} THEN 1 ELSE 0 END) as slow_count,
    ROUND(100.0 * SUM(CASE WHEN dur > ${vsync_env.data[0].vsync_period_ns} * ${slow_composition_multiplier|1.5} THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 1) as slow_pct
  FROM sf_compositions
),
-- Fence 统计
fence_stats AS (
  SELECT
    COUNT(*) as fence_count,
    AVG(s.dur) / 1e6 as avg_fence_ms,
    MAX(s.dur) / 1e6 as max_fence_ms,
    SUM(CASE WHEN s.dur > ${long_fence_threshold_ms|10} * 1000000 THEN 1 ELSE 0 END) as long_fence_count
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = 'surfaceflinger' OR p.name = '/system/bin/surfaceflinger')
    AND (s.name GLOB '*fence*' OR s.name GLOB '*Fence*')
    AND s.dur > 1000000
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
),
-- GPU 合成检测
gpu_comp_stats AS (
  SELECT
    COUNT(*) as gpu_comp_count
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = 'surfaceflinger' OR p.name = '/system/bin/surfaceflinger')
    AND (s.name GLOB '*GPU*' OR s.name GLOB '*gpu*' OR s.name GLOB '*GLES*')
    AND s.dur > 0
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
),
analysis AS (
  SELECT
    COALESCE((SELECT total_count FROM composition_stats), 0) as total_compositions,
    COALESCE((SELECT slow_count FROM composition_stats), 0) as slow_compositions,
    COALESCE((SELECT slow_pct FROM composition_stats), 0) as slow_pct,
    COALESCE((SELECT avg_dur_ms FROM composition_stats), 0) as avg_dur_ms,
    COALESCE((SELECT max_dur_ms FROM composition_stats), 0) as max_dur_ms,
    COALESCE((SELECT long_fence_count FROM fence_stats), 0) as long_fence_count,
    COALESCE((SELECT max_fence_ms FROM fence_stats), 0) as max_fence_ms,
    COALESCE((SELECT gpu_comp_count FROM gpu_comp_stats), 0) as gpu_comp_count
)
SELECT
  -- SF 问题分类
  CASE
    WHEN (SELECT slow_pct FROM analysis) > ${slow_pct_threshold|10} AND (SELECT avg_dur_ms FROM analysis) > ${composition_rating_poor_ms|12} THEN 'COMPOSITION_SLOW'
    WHEN (SELECT gpu_comp_count FROM analysis) > (SELECT total_compositions FROM analysis) * ${gpu_comp_ratio_threshold|0.5}
         AND (SELECT avg_dur_ms FROM analysis) > ${composition_rating_fair_ms|8} THEN 'GPU_COMPOSITION_HEAVY'
    WHEN (SELECT long_fence_count FROM analysis) > 5
         AND (SELECT max_fence_ms FROM analysis) > ${fence_critical_ms|16} THEN 'FENCE_TIMEOUT'
    WHEN (SELECT slow_compositions FROM analysis) > 0 THEN 'OCCASIONAL_SLOW'
    ELSE 'NORMAL'
  END as sf_category,
  -- 置信度
  CASE
    WHEN (SELECT slow_pct FROM analysis) > ${slow_pct_threshold|10} THEN 0.85
    WHEN (SELECT long_fence_count FROM analysis) > 5 THEN 0.8
    WHEN (SELECT gpu_comp_count FROM analysis) > (SELECT total_compositions FROM analysis) * ${gpu_comp_ratio_threshold|0.5} THEN 0.75
    WHEN (SELECT slow_compositions FROM analysis) > 0 THEN 0.65
    ELSE 0.6
  END as confidence,
  -- 根因总结
  CASE
    WHEN (SELECT slow_pct FROM analysis) > ${slow_pct_threshold|10} AND (SELECT avg_dur_ms FROM analysis) > ${composition_rating_poor_ms|12} THEN
      '合成延迟: ' || (SELECT slow_compositions FROM analysis) || ' 次慢合成 (' || (SELECT slow_pct FROM analysis) || '%)，平均 ' || ROUND((SELECT avg_dur_ms FROM analysis), 1) || 'ms'
    WHEN (SELECT gpu_comp_count FROM analysis) > (SELECT total_compositions FROM analysis) * ${gpu_comp_ratio_threshold|0.5}
         AND (SELECT avg_dur_ms FROM analysis) > ${composition_rating_fair_ms|8} THEN
      'GPU 合成负载高: GPU 合成 ' || (SELECT gpu_comp_count FROM analysis) || ' 次，平均合成耗时 ' || ROUND((SELECT avg_dur_ms FROM analysis), 1) || 'ms'
    WHEN (SELECT long_fence_count FROM analysis) > 5 THEN
      'Fence 超时: ' || (SELECT long_fence_count FROM analysis) || ' 次 Fence 等待超过 10ms，最大 ' || ROUND((SELECT max_fence_ms FROM analysis), 1) || 'ms'
    WHEN (SELECT slow_compositions FROM analysis) > 0 THEN
      '偶发慢合成: ' || (SELECT slow_compositions FROM analysis) || ' 次慢合成，最大 ' || ROUND((SELECT max_dur_ms FROM analysis), 1) || 'ms'
    ELSE
      'SurfaceFlinger 合成性能正常'
  END as root_cause_summary,
  -- 证据
  '[' ||
    '"总合成数: ' || (SELECT total_compositions FROM analysis) || '",' ||
    '"慢合成数: ' || (SELECT slow_compositions FROM analysis) || ' (' || (SELECT slow_pct FROM analysis) || '%)",' ||
    '"平均合成耗时: ' || ROUND(COALESCE((SELECT avg_dur_ms FROM analysis), 0), 1) || 'ms",' ||
    '"最大合成耗时: ' || ROUND(COALESCE((SELECT max_dur_ms FROM analysis), 0), 1) || 'ms",' ||
    '"长 Fence 次数: ' || (SELECT long_fence_count FROM analysis) || '",' ||
    '"GPU 合成次数: ' || (SELECT gpu_comp_count FROM analysis) || '"' ||
  ']' as evidence,
  -- 优化建议
  CASE
    WHEN (SELECT slow_pct FROM analysis) > ${slow_pct_threshold|10} THEN
      '减少同时可见的 Layer 数量，简化 Layer 特效'
    WHEN (SELECT gpu_comp_count FROM analysis) > (SELECT total_compositions FROM analysis) * ${gpu_comp_ratio_threshold|0.5} THEN
      '减少需要 GPU 合成的 Layer，检查是否可以使用 HWC 合成'
    WHEN (SELECT long_fence_count FROM analysis) > 5 THEN
      '检查 GPU 负载，可能 GPU 工作队列积压导致 Fence 延迟'
    WHEN (SELECT slow_compositions FROM analysis) > 0 THEN
      '偶发问题，检查慢合成时刻的系统负载'
    ELSE
      'SurfaceFlinger 运行正常，无需优化'
  END as suggestion
