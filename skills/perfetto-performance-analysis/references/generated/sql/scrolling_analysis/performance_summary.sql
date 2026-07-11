-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH
-- 获取 VSync 周期（从 VSYNC-sf 信号计算，限定在分析区间内）
vsync_intervals AS (
  SELECT
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
timing_config AS (
  SELECT CASE
    WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
    WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
    WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
    WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
    WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
    WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
    ELSE raw_ns
  END AS vsync_period_ns
  FROM (
    SELECT CAST(COALESCE(
      (SELECT PERCENTILE(interval_ns, 0.5)
       FROM vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
time_range AS (
  SELECT
    MIN(a.ts) as start_ts,
    MAX(a.ts + a.dur) as end_ts,
    MAX(a.ts + a.dur) - MIN(a.ts) as duration_ns
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
app_frame_intervals AS (
  SELECT
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts, COALESCE(a.display_frame_token, a.surface_frame_token)) as prev_present_ts
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
valid_frame_intervals AS (
  SELECT
    present_ts - prev_present_ts as frame_interval_ns
  FROM app_frame_intervals
  WHERE prev_present_ts IS NOT NULL
    AND present_ts > prev_present_ts
    AND present_ts - prev_present_ts >= (SELECT vsync_period_ns FROM timing_config) * 0.5
    AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM timing_config) * 6
),
-- App 报告的掉帧（旧逻辑，仅供参考）
app_stats AS (
  SELECT
    COUNT(*) as total,
    SUM(CASE WHEN jank_type != 'None' THEN 1 ELSE 0 END) as app_janky_frames,
    COALESCE(
      (SELECT CAST(ROUND(AVG(frame_interval_ns)) AS INTEGER) FROM valid_frame_intervals),
      CAST(ROUND(AVG(CASE WHEN dur > 0 THEN dur ELSE NULL END)) AS INTEGER),
      0
    ) as avg_present_interval,
    COALESCE(
      (SELECT CAST(MAX(frame_interval_ns) AS INTEGER) FROM valid_frame_intervals),
      MAX(CASE WHEN dur > 0 THEN dur ELSE NULL END),
      0
    ) as max_present_interval,
    COALESCE(
      (SELECT CAST(ROUND(PERCENTILE(frame_interval_ns, 0.5)) AS INTEGER) FROM valid_frame_intervals),
      CAST(ROUND(PERCENTILE(CASE WHEN dur > 0 THEN dur ELSE NULL END, 0.5)) AS INTEGER),
      0
    ) as median_present_interval,
    COALESCE(
      (SELECT CAST(ROUND(PERCENTILE(frame_interval_ns, 0.95)) AS INTEGER) FROM valid_frame_intervals),
      CAST(ROUND(PERCENTILE(CASE WHEN dur > 0 THEN dur ELSE NULL END, 0.95)) AS INTEGER),
      0
    ) as p95_present_interval,
    COALESCE(
      (SELECT CAST(ROUND(PERCENTILE(frame_interval_ns, 0.99)) AS INTEGER) FROM valid_frame_intervals),
      CAST(ROUND(PERCENTILE(CASE WHEN dur > 0 THEN dur ELSE NULL END, 0.99)) AS INTEGER),
      0
    ) as p99_present_interval
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
-- Per-layer 帧序列：双信号混合检测基础数据
-- present_type = SurfaceFlinger 的消费状态（非 BS 帧的权威信号）
-- present_ts interval = BS 帧的二次验证信号（区分真实掉帧 vs 管线背压）
consumer_layer_frames AS (
  SELECT
    COALESCE(a.display_frame_token, a.surface_frame_token) as display_frame_token,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts) as prev_present_ts,
    COALESCE(a.jank_type, 'None') as jank_type,
    COALESCE(a.present_type, 'Unknown Present') as present_type,
    a.layer_name
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
-- 掉帧检测：双信号混合策略
-- 非 BS 帧：present_type IN ('Late Present', 'Dropped Frame') 为权威信号
-- BS 帧：present_type 始终为 Late Present，需用 present_ts 间隔作为二次验证
--        间隔 > 1.5x vsync = 真实掉帧（被 BS 掩盖）；否则 = 管线背压（非感知掉帧）
consumer_gap_stats AS (
  SELECT
    COUNT(*) as total_frames,
    -- 感知掉帧：双信号混合检测
    SUM(CASE
      WHEN present_type IN ('Late Present', 'Dropped Frame')
        AND jank_type != 'Buffer Stuffing' THEN 1
      WHEN jank_type = 'Buffer Stuffing'
        AND prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM timing_config) * 1.5
        AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM timing_config) * 6 THEN 1
      ELSE 0
    END) as consumer_jank_frames,
    -- App 侧掉帧（BS 帧的 jank_type 不可能是 Self Jank/App Deadline Missed/App Resynced Jitter，无需双信号）
    SUM(CASE WHEN present_type IN ('Late Present', 'Dropped Frame')
      AND jank_type IN ('Self Jank', 'App Deadline Missed', 'App Resynced Jitter') THEN 1 ELSE 0 END) as app_jank_frames,
    -- Buffer Stuffing 总帧数（管线背压，含正常 BS 和异常 BS）
    SUM(CASE WHEN jank_type = 'Buffer Stuffing' THEN 1 ELSE 0 END) as buffer_stuffing_frames,
    -- vsync missed：双信号门控
    SUM(CASE
      WHEN (
        (present_type IN ('Late Present', 'Dropped Frame') AND jank_type != 'Buffer Stuffing')
        OR (jank_type = 'Buffer Stuffing' AND prev_present_ts IS NOT NULL
            AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM timing_config) * 1.5
            AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM timing_config) * 6)
      ) AND prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM timing_config) * 1.5
      THEN MAX(CAST(ROUND((present_ts - prev_present_ts) * 1.0 / (SELECT vsync_period_ns FROM timing_config) - 1, 0) AS INTEGER), 0)
      ELSE 0
    END) as total_vsync_missed,
    MAX(CASE
      WHEN (
        (present_type IN ('Late Present', 'Dropped Frame') AND jank_type != 'Buffer Stuffing')
        OR (jank_type = 'Buffer Stuffing' AND prev_present_ts IS NOT NULL
            AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM timing_config) * 1.5
            AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM timing_config) * 6)
      ) AND prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM timing_config) * 1.5
      THEN MAX(CAST(ROUND((present_ts - prev_present_ts) * 1.0 / (SELECT vsync_period_ns FROM timing_config) - 1, 0) AS INTEGER), 0)
      ELSE 0
    END) as max_vsync_missed
  FROM consumer_layer_frames
),
resolved_jank AS (
  SELECT
    COALESCE((SELECT consumer_jank_frames FROM consumer_gap_stats), (SELECT app_janky_frames FROM app_stats), 0) as janky_frames,
    COALESCE((SELECT app_jank_frames FROM consumer_gap_stats), (SELECT app_janky_frames FROM app_stats), 0) as app_janky_frames,
    -- 感知掉帧 = consumer_jank_frames（双信号已过滤掉正常 BS 帧）
    COALESCE((SELECT consumer_jank_frames FROM consumer_gap_stats), (SELECT app_janky_frames FROM app_stats), 0) as perceived_jank_frames,
    COALESCE((SELECT buffer_stuffing_frames FROM consumer_gap_stats), 0) as buffer_stuffing_frames,
    COALESCE((SELECT max_vsync_missed FROM consumer_gap_stats), 0) as max_vsync_missed,
    COALESCE((SELECT total_vsync_missed FROM consumer_gap_stats), 0) as total_vsync_missed,
    'present_type' as fps_source
)
SELECT
  (SELECT total FROM app_stats) as total_frames,
  -- 感知掉帧（排除 Buffer Stuffing）— 用户真正能感知到的掉帧
  (SELECT perceived_jank_frames FROM resolved_jank) as perceived_jank_frames,
  -- 感知掉帧率（主指标，用于 rating）
  ROUND(
    100.0 * (SELECT perceived_jank_frames FROM resolved_jank) / NULLIF((SELECT total FROM app_stats), 0),
    2
  ) as jank_rate,
  -- Buffer Stuffing 帧数（管线背压，非 App 逻辑问题）
  (SELECT buffer_stuffing_frames FROM resolved_jank) as buffer_stuffing_frames,
  -- 总掉帧数（含 Buffer Stuffing，用于完整性展示）
  (SELECT janky_frames FROM resolved_jank) as janky_frames,
  (SELECT app_janky_frames FROM resolved_jank) as app_janky_frames,
  MAX(
    (SELECT perceived_jank_frames FROM resolved_jank) -
    (SELECT app_janky_frames FROM resolved_jank),
    0
  ) as sf_jank_count,
  -- App 侧掉帧率
  ROUND(
    100.0 * (SELECT app_janky_frames FROM resolved_jank) / NULLIF((SELECT total FROM app_stats), 0),
    2
  ) as app_jank_rate,
  -- Buffer Stuffing 率
  ROUND(
    100.0 * (SELECT buffer_stuffing_frames FROM resolved_jank) / NULLIF((SELECT total FROM app_stats), 0),
    2
  ) as buffer_stuffing_rate,
  (SELECT avg_present_interval FROM app_stats) as avg_frame_dur,
  (SELECT max_present_interval FROM app_stats) as max_frame_dur,
  (SELECT median_present_interval FROM app_stats) as median_frame_dur,
  (SELECT p95_present_interval FROM app_stats) as p95_frame_dur,
  (SELECT p99_present_interval FROM app_stats) as p99_frame_dur,
  ROUND((SELECT duration_ns FROM time_range) / 1e9, 2) as duration_sec,
  MIN(
    ROUND(1e9 * (SELECT total FROM app_stats) / NULLIF((SELECT duration_ns FROM time_range), 0), 1),
    CAST(ROUND(1e9 / (SELECT vsync_period_ns FROM timing_config)) AS INTEGER)
  ) as actual_fps,
  CAST(ROUND(1e9 / (SELECT vsync_period_ns FROM timing_config)) AS INTEGER) as refresh_rate,
  -- 评级基于感知掉帧率（排除 Buffer Stuffing）
  CASE
    WHEN (SELECT perceived_jank_frames FROM resolved_jank) = 0 THEN '优秀'
    WHEN 100.0 * (SELECT perceived_jank_frames FROM resolved_jank) / NULLIF((SELECT total FROM app_stats), 0) < 1 THEN '优秀'
    WHEN 100.0 * (SELECT perceived_jank_frames FROM resolved_jank) / NULLIF((SELECT total FROM app_stats), 0) < 5 THEN '良好'
    WHEN 100.0 * (SELECT perceived_jank_frames FROM resolved_jank) / NULLIF((SELECT total FROM app_stats), 0) < 15 THEN '一般'
    ELSE '较差'
  END as rating,
  (SELECT fps_source FROM resolved_jank) as fps_source,
  (SELECT max_vsync_missed FROM resolved_jank) as max_vsync_missed,
  (SELECT total_vsync_missed FROM resolved_jank) as total_vsync_missed,
  ROUND((SELECT vsync_period_ns FROM timing_config) / 1e6, 2) as vsync_period_ms
LIMIT 1
