-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: 700737c3b798446d259b725cdb99906ea5b2a4b8b3a6334401f1cc18b352b061

WITH
-- GPU 频率统计
gpu_freq_stats AS (
  SELECT
    gpu_id,
    MAX(gpu_freq) as max_gpu_freq,
    SUM(gpu_freq * dur) * 1.0 / NULLIF(SUM(dur), 0) as weighted_avg_freq,
    SUM(dur) as total_dur
  FROM android_gpu_frequency
  WHERE dur > 0
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
  GROUP BY gpu_id
),
-- 最高频运行时间占比
max_freq_ratio AS (
  SELECT
    g.gpu_id,
    ROUND(100.0 * SUM(CASE WHEN g.gpu_freq = s.max_gpu_freq THEN g.dur ELSE 0 END) / NULLIF(SUM(g.dur), 0), 1) as max_freq_pct,
    -- 高频区间 (>=90% max) 占比
    ROUND(100.0 * SUM(CASE WHEN g.gpu_freq >= s.max_gpu_freq * 0.9 THEN g.dur ELSE 0 END) / NULLIF(SUM(g.dur), 0), 1) as high_freq_pct,
    -- 低频区间 (<=30% max) 占比
    ROUND(100.0 * SUM(CASE WHEN g.gpu_freq <= s.max_gpu_freq * 0.3 THEN g.dur ELSE 0 END) / NULLIF(SUM(g.dur), 0), 1) as low_freq_pct
  FROM android_gpu_frequency g
  JOIN gpu_freq_stats s ON g.gpu_id = s.gpu_id
  WHERE g.dur > 0
    AND (${start_ts} IS NULL OR g.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR g.ts < ${end_ts})
  GROUP BY g.gpu_id
),
-- 频率下降检测 (可能的降频/限频)
freq_drops AS (
  SELECT
    gpu_id,
    COUNT(*) as drop_count
  FROM android_gpu_frequency
  WHERE prev_gpu_freq IS NOT NULL
    AND gpu_freq < prev_gpu_freq * ${freq_drop_ratio|0.7}  -- 频率突降 >30%
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
  GROUP BY gpu_id
),
-- GPU-帧关联 (如果有帧数据)
frame_stats AS (
  SELECT
    COUNT(*) as total_frames,
    SUM(CASE WHEN jank_type GLOB '*GPU*' THEN 1 ELSE 0 END) as gpu_jank_frames
  FROM actual_frame_timeline_slice
  WHERE dur > 0
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
analysis AS (
  SELECT
    COALESCE((SELECT max_freq_pct FROM max_freq_ratio LIMIT 1), 0) as max_freq_pct,
    COALESCE((SELECT high_freq_pct FROM max_freq_ratio LIMIT 1), 0) as high_freq_pct,
    COALESCE((SELECT low_freq_pct FROM max_freq_ratio LIMIT 1), 0) as low_freq_pct,
    COALESCE((SELECT drop_count FROM freq_drops LIMIT 1), 0) as freq_drop_count,
    COALESCE((SELECT gpu_jank_frames FROM frame_stats), 0) as gpu_jank_frames,
    COALESCE((SELECT total_frames FROM frame_stats), 0) as total_frames
),
-- One classification; every column below follows it, so they cannot drift apart.
verdict AS (
  SELECT a.*,
    CASE
      WHEN high_freq_pct > ${high_freq_threshold_pct|70} THEN 'GPU_BOUND'
      WHEN freq_drop_count > ${freq_drop_count_threshold|20} AND high_freq_pct > 30 THEN 'GPU_FREQ_DROPS'
      WHEN low_freq_pct > ${high_freq_threshold_pct|70} THEN 'GPU_IDLE'
      WHEN gpu_jank_frames > 0 THEN 'GPU_JANK_RELATED'
      ELSE 'NORMAL'
    END AS gpu_category
  FROM analysis a
)
SELECT
  gpu_category,
  CASE gpu_category
    WHEN 'GPU_BOUND' THEN 0.9
    WHEN 'GPU_FREQ_DROPS' THEN 0.75
    WHEN 'GPU_IDLE' THEN 0.85
    WHEN 'GPU_JANK_RELATED' THEN 0.7
    ELSE 0.6
  END as confidence,
  CASE gpu_category
    WHEN 'GPU_BOUND' THEN
      'GPU 瓶颈: 高频区间 (>=90%最高频) 运行时间占 ' || high_freq_pct || '%，GPU 持续满载'
    WHEN 'GPU_FREQ_DROPS' THEN
      'GPU 频率突降: 检测到 ' || freq_drop_count || ' 次（仅为频率观测：可能来自负载变化、DVFS 调速或频率上限，本 Skill 未采集 GPU 频率上限证据，是否限频未判定）'
    WHEN 'GPU_IDLE' THEN
      'GPU 空闲: 低频区间运行时间占 ' || low_freq_pct || '%，GPU 负载极低'
    WHEN 'GPU_JANK_RELATED' THEN
      'GPU 相关掉帧: 检测到 ' || gpu_jank_frames || ' 帧 GPU 相关 Jank'
    ELSE
      'GPU 状态正常，频率分布合理'
  END as root_cause_summary,
  '[' ||
    '"最高频占比: ' || max_freq_pct || '%",' ||
    '"高频区间占比: ' || high_freq_pct || '%",' ||
    '"低频区间占比: ' || low_freq_pct || '%",' ||
    '"频率突降次数: ' || freq_drop_count || '",' ||
    '"GPU 相关掉帧: ' || gpu_jank_frames || '"' ||
  ']' as evidence,
  CASE gpu_category
    WHEN 'GPU_BOUND' THEN '减少 GPU 负载：简化 shader、降低绘制复杂度、减少 overdraw'
    WHEN 'GPU_FREQ_DROPS' THEN '结合 GPU 负载与 DVFS 调速记录核对频率突降的原因；仅凭频率变化不能据此判定限频或温控'
    WHEN 'GPU_IDLE' THEN 'GPU 空闲，性能瓶颈不在 GPU 侧'
    WHEN 'GPU_JANK_RELATED' THEN '检查 GPU 渲染管线，优化 RenderThread 工作负载'
    ELSE '当前 GPU 运行状态良好，无需特别优化'
  END as suggestion
FROM verdict
