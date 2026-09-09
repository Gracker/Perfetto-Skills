-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 2dcba698d9cc63e045e9346afc44cab60148cf55a58161bf0378383d624af4ff
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Keep the process table available for global/peer joins. Only an explicitly
-- authored target relation consumes this trusted execution scope.
effective_target_processes AS (
  SELECT * FROM process
  WHERE ${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid}
)
,
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
      (SELECT PERCENTILE(interval_ns, 50)
       FROM vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
-- APP_FRAME_DEDUP_CTES_BEGIN
app_frame_rows AS (
  SELECT
    a.*,
    CASE
      WHEN a.display_frame_token IS NOT NULL
        THEN 'display:' || CAST(a.display_frame_token AS TEXT)
      WHEN a.surface_frame_token IS NOT NULL
        THEN 'surface:' || COALESCE(a.layer_name, '') || ':' || CAST(a.surface_frame_token AS TEXT)
      ELSE NULL
    END as frame_key
  FROM actual_frame_timeline_slice a
  JOIN effective_target_processes p ON a.upid = p.upid
  WHERE (
    ${__process_scope.upid} IS NOT NULL OR '${package}' = ''
    OR p.name = '${package}'
    OR p.name GLOB '${package}:*'
  )
    AND p.name NOT LIKE '/system/%'
    -- With no target package the clause above accepts any process, and
    -- the system UI is the one most likely to be drawing while the target
    -- app draws nothing. Its frames are punctual, so they read back as
    -- flawless scrolling for an app that produced no frames at all: one
    -- device reported 31fps SystemUI frames as "优秀", another rated a
    -- 5-frame notification-shade window. Anyone analysing the system UI
    -- deliberately names it and keeps these rows.
    AND ('${package}' != '' OR p.name NOT LIKE 'com.android.systemui%')
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND (a.display_frame_token IS NOT NULL OR a.surface_frame_token IS NOT NULL)
),
-- APP_FRAME_DEDUP_CTES_END
-- FRAME_TIME_RANGE_CTES_BEGIN
display_frame_times AS (
  SELECT
    frame_key,
    MIN(ts) as frame_ts,
    MAX(ts + CASE WHEN dur > 0 THEN dur ELSE 0 END) as present_ts
  FROM app_frame_rows
  GROUP BY frame_key
),
ordered_display_frames AS (
  SELECT
    frame_key,
    frame_ts,
    present_ts,
    MAX(present_ts) OVER (
      ORDER BY frame_ts, frame_key
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) as prev_present_ts
  FROM display_frame_times
),
frame_time_range_stats AS (
  SELECT
    MIN(frame_ts) as start_ts,
    MAX(present_ts) as end_ts,
    MAX(present_ts) - MIN(frame_ts) as raw_duration_ns,
    COALESCE(SUM(
      CASE
        WHEN prev_present_ts IS NOT NULL
          AND frame_ts - prev_present_ts > (SELECT vsync_period_ns * 6 FROM timing_config)
        THEN frame_ts - prev_present_ts
        ELSE 0
      END
    ), 0) as inter_session_idle_ns,
    COALESCE(SUM(
      CASE
        WHEN prev_present_ts IS NOT NULL
          AND frame_ts - prev_present_ts > (SELECT vsync_period_ns * 6 FROM timing_config)
        THEN 1
        ELSE 0
      END
    ), 0) as session_break_count
  FROM ordered_display_frames
),
time_range AS (
  SELECT
    start_ts,
    end_ts,
    raw_duration_ns,
    inter_session_idle_ns,
    session_break_count,
    CASE
      WHEN raw_duration_ns IS NULL OR raw_duration_ns <= 0
        THEN (SELECT vsync_period_ns FROM timing_config)
      ELSE MAX(
        raw_duration_ns - inter_session_idle_ns,
        (SELECT vsync_period_ns FROM timing_config)
      )
    END as duration_ns
  FROM frame_time_range_stats
),
-- FRAME_TIME_RANGE_CTES_END
app_frame_intervals AS (
  SELECT
    ts + CASE WHEN dur > 0 THEN dur ELSE 0 END as present_ts,
    LAG(ts + CASE WHEN dur > 0 THEN dur ELSE 0 END)
      OVER (PARTITION BY layer_name ORDER BY ts, frame_key) as prev_present_ts
  FROM app_frame_rows
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
    COUNT(DISTINCT frame_key) as total,
    COUNT(DISTINCT CASE WHEN jank_type != 'None' THEN frame_key END) as app_janky_frames,
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
      (SELECT CAST(ROUND(PERCENTILE(frame_interval_ns, 50)) AS INTEGER) FROM valid_frame_intervals),
      CAST(ROUND(PERCENTILE(CASE WHEN dur > 0 THEN dur ELSE NULL END, 50)) AS INTEGER),
      0
    ) as median_present_interval,
    COALESCE(
      (SELECT CAST(ROUND(PERCENTILE(frame_interval_ns, 95)) AS INTEGER) FROM valid_frame_intervals),
      CAST(ROUND(PERCENTILE(CASE WHEN dur > 0 THEN dur ELSE NULL END, 95)) AS INTEGER),
      0
    ) as p95_present_interval,
    COALESCE(
      (SELECT CAST(ROUND(PERCENTILE(frame_interval_ns, 99)) AS INTEGER) FROM valid_frame_intervals),
      CAST(ROUND(PERCENTILE(CASE WHEN dur > 0 THEN dur ELSE NULL END, 99)) AS INTEGER),
      0
    ) as p99_present_interval
  FROM app_frame_rows
),
-- Per-layer 帧序列：双信号混合检测基础数据
-- present_type = SurfaceFlinger 的消费状态（非 BS 帧的权威信号）
-- present_ts interval = BS 帧的二次验证信号（区分真实掉帧 vs 管线背压）
consumer_layer_frames AS (
  SELECT
    frame_key,
    COALESCE(a.display_frame_token, a.surface_frame_token) as display_frame_token,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.upid, a.layer_name ORDER BY a.ts) as prev_present_ts,
    COALESCE(a.jank_type, 'None') as jank_type,
    COALESCE(a.present_type, 'Unknown Present') as present_type,
    CASE
      WHEN a.jank_type GLOB '*Self Jank*' OR android_is_app_jank_type(a.jank_type) THEN 'APP'
      WHEN a.jank_type GLOB '*SurfaceFlinger*' THEN 'SF'
      WHEN a.jank_type GLOB '*Buffer Stuffing*' THEN 'BUFFER_STUFFING'
      WHEN android_is_sf_jank_type(a.jank_type) THEN 'SF'
      WHEN a.jank_type = 'None' OR a.jank_type IS NULL THEN 'HIDDEN'
      ELSE 'UNKNOWN'
    END as jank_responsibility,
    a.layer_name
  FROM app_frame_rows a
),
-- 掉帧检测：双信号混合策略
-- 非 BS 帧：present_type IN ('Late Present', 'Dropped Frame') 为权威信号
-- BS 帧：present_type 始终为 Late Present，需用 present_ts 间隔作为二次验证
--        间隔 > 1.5x vsync = 真实掉帧（被 BS 掩盖）；否则 = 管线背压（非感知掉帧）
consumer_frame_signals AS (
  SELECT
    frame_key,
    CASE
      WHEN present_type IN ('Late Present', 'Dropped Frame')
        AND (jank_responsibility != 'BUFFER_STUFFING' OR android_is_missed_frame_type(jank_type)) THEN 1
      WHEN jank_responsibility = 'BUFFER_STUFFING'
        AND prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM timing_config) * 1.5
        AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM timing_config) * 6 THEN 1
      ELSE 0
    END as consumer_jank,
    CASE
      WHEN present_type IN ('Late Present', 'Dropped Frame')
        AND jank_responsibility = 'APP' THEN 1
      ELSE 0
    END as app_jank,
    CASE WHEN jank_responsibility = 'BUFFER_STUFFING' THEN 1 ELSE 0 END as buffer_stuffing,
    CASE
      WHEN (
        (present_type IN ('Late Present', 'Dropped Frame')
          AND (jank_responsibility != 'BUFFER_STUFFING' OR android_is_missed_frame_type(jank_type)))
        OR (jank_responsibility = 'BUFFER_STUFFING' AND prev_present_ts IS NOT NULL
            AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM timing_config) * 1.5
            AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM timing_config) * 6)
      ) AND prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM timing_config) * 1.5
      THEN MAX(CAST(ROUND((present_ts - prev_present_ts) * 1.0 / (SELECT vsync_period_ns FROM timing_config) - 1, 0) AS INTEGER), 0)
      ELSE 0
    END as vsync_missed
  FROM consumer_layer_frames
),
display_frame_signals AS (
  SELECT
    frame_key,
    MAX(consumer_jank) as consumer_jank,
    MAX(app_jank) as app_jank,
    MAX(buffer_stuffing) as buffer_stuffing,
    MAX(vsync_missed) as vsync_missed
  FROM consumer_frame_signals
  GROUP BY frame_key
),
consumer_gap_stats AS (
  SELECT
    COUNT(*) as total_frames,
    SUM(consumer_jank) as consumer_jank_frames,
    SUM(app_jank) as app_jank_frames,
    SUM(buffer_stuffing) as buffer_stuffing_frames,
    SUM(vsync_missed) as total_vsync_missed,
    MAX(vsync_missed) as max_vsync_missed
  FROM display_frame_signals
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
  -- 评级基于感知掉帧率（排除 Buffer Stuffing），但先过两道门。
  CASE
    -- ① 样本量门槛。5 帧（一次 65ms 通知栏窗口）曾被评成「较差」——
    -- 那不是评价，是把噪声打扮成结论。20 帧在 120Hz 下不到 0.2s、
    -- 60Hz 下不到 0.4s，真实的短手势仍然评得出来。
    WHEN (SELECT total FROM app_stats) < 20 THEN '样本不足'
    -- ② 帧率达成率门槛。只看掉帧率时，120Hz 屏上 31fps 因为「每一帧都准时」
    -- 被评成「优秀」。准时地少给一半以上的帧不是优秀。
    WHEN MIN(
           ROUND(1e9 * (SELECT total FROM app_stats) / NULLIF((SELECT duration_ns FROM time_range), 0), 1),
           CAST(ROUND(1e9 / (SELECT vsync_period_ns FROM timing_config)) AS INTEGER)
         ) < CAST(ROUND(1e9 / (SELECT vsync_period_ns FROM timing_config)) AS INTEGER) * 0.5
      THEN '一般'
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
