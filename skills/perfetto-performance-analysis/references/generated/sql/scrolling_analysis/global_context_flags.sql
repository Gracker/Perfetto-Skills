-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH
-- 1. 视频解码活动检测：滑动期间是否有 MediaCodec/视频线程活跃
video_check AS (
  SELECT COUNT(*) as video_slice_count
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE (t.name GLOB '*MediaCodec*' OR t.name GLOB '*CodecLooper*'
         OR t.name GLOB '*VideoDecoder*' OR t.name GLOB '*NuPlayer*'
         OR s.name GLOB '*queueVideoBuffer*' OR s.name GLOB '*onOutputBufferAvailable*')
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts + s.dur < ${end_ts})
    AND s.dur > 100000
),
-- 2. 插帧帧数检测：frame_id = -1 通常是 OEM 插帧功能
interpolation_check AS (
  SELECT COUNT(*) as interpolation_frame_count
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND COALESCE(a.display_frame_token, -999) = -1
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
),
-- 3. 温控活跃检测：trace 中是否有明显的频率天花板下降
-- 对比全程峰值 vs 尾部 2s 内最低值，检测持续降频趋势
cpufreq_tail_threshold AS (
  SELECT MAX(c.ts) - 2000000000 AS threshold
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id AND cct.name = 'cpufreq'
  LEFT JOIN _cpu_topology ct ON cct.cpu = ct.cpu_id
  WHERE ct.core_type IN ('prime', 'big')
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
thermal_check AS (
  SELECT
    COALESCE(ROUND(MAX(c.value) / 1000, 0), 0) as trace_peak_freq_mhz,
    COALESCE(ROUND(MIN(
      CASE WHEN c.ts > (SELECT threshold FROM cpufreq_tail_threshold) THEN c.value END
    ) / 1000, 0), 0) as tail_min_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id AND cct.name = 'cpufreq'
  LEFT JOIN _cpu_topology ct ON cct.cpu = ct.cpu_id
  WHERE ct.core_type IN ('prime', 'big')
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
-- 4. 非 App 大核 CPU 占用（后台干扰指标）
background_cpu AS (
  SELECT
    ROUND(100.0 * SUM(CASE WHEN '${package}' != '' AND p.name NOT GLOB '${package}*' AND ts.state = 'Running' THEN ts.dur ELSE 0 END)
      / NULLIF(SUM(CASE WHEN ts.state = 'Running' THEN ts.dur ELSE 0 END), 0), 1) as non_app_big_core_pct
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ct.core_type IN ('prime', 'big')
    AND (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
    AND ts.dur > 0
)
SELECT
  CASE WHEN COALESCE(v.video_slice_count, 0) > 20 THEN 1 ELSE 0 END as video_during_scroll,
  COALESCE(v.video_slice_count, 0) as video_slice_count,
  COALESCE(i.interpolation_frame_count, 0) as interpolation_frame_count,
  CASE WHEN COALESCE(i.interpolation_frame_count, 0) > 10 THEN 1 ELSE 0 END as interpolation_active,
  th.trace_peak_freq_mhz,
  th.tail_min_freq_mhz,
  -- thermal_trending 仅在分析窗口 >5s 时有效（短 trace 正常 governor 波动会误报）
  CASE WHEN th.trace_peak_freq_mhz > 0 AND th.tail_min_freq_mhz > 0
    AND th.tail_min_freq_mhz < th.trace_peak_freq_mhz * 0.70
    AND (SELECT threshold FROM cpufreq_tail_threshold) > COALESCE(${start_ts}, 0)
    THEN 1 ELSE 0 END as thermal_trending,
  COALESCE(bg.non_app_big_core_pct, 0) as non_app_big_core_pct,
  CASE WHEN COALESCE(bg.non_app_big_core_pct, 0) > 60 THEN 1 ELSE 0 END as background_cpu_heavy
FROM video_check v, interpolation_check i, thermal_check th, background_cpu bg
