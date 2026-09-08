-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 6ebd984e1b34cb456d5fa410b4e2308e350c5854086ec1e06ff58b4c80c5ef4f
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
vsync_intervals AS (
  SELECT
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_config AS (
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
app_frames AS (
  SELECT
    CASE
      WHEN a.display_frame_token IS NOT NULL
        THEN 'display:' || CAST(a.display_frame_token AS TEXT)
      WHEN a.surface_frame_token IS NOT NULL
        THEN 'surface:' || COALESCE(a.layer_name, '') || ':' || CAST(a.surface_frame_token AS TEXT)
      ELSE NULL
    END as frame_key,
    COALESCE(a.display_frame_token, a.surface_frame_token) as display_frame_token,
    a.ts,
    CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as dur,
    COALESCE(a.jank_type, 'Unknown') as jank_type,
    COALESCE(a.present_type, 'Unknown Present') as present_type,
    CASE
      WHEN a.jank_type GLOB '*Self Jank*' OR android_is_app_jank_type(a.jank_type) THEN 'APP'
      WHEN a.jank_type GLOB '*SurfaceFlinger*' THEN 'SF'
      WHEN a.jank_type GLOB '*Buffer Stuffing*' THEN 'BUFFER_STUFFING'
      WHEN android_is_sf_jank_type(a.jank_type) THEN 'SF'
      WHEN a.jank_type = 'None' OR a.jank_type IS NULL THEN 'HIDDEN'
      ELSE 'UNKNOWN'
    END as jank_responsibility,
    a.layer_name,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.upid, a.layer_name ORDER BY a.ts) as prev_present_ts
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
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
-- 掉帧检测：双信号混合策略
jank_row_signals AS (
  SELECT
    frame_key,
    jank_type,
    dur,
    layer_name,
    -- is_consumer_jank: 双信号混合检测
    CASE
      WHEN present_type IN ('Late Present', 'Dropped Frame')
        AND (jank_responsibility != 'BUFFER_STUFFING' OR android_is_missed_frame_type(jank_type)) THEN 1
      WHEN jank_responsibility = 'BUFFER_STUFFING'
        AND prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM vsync_config) * 1.5
        AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM vsync_config) * 6 THEN 1
      ELSE 0
    END as row_is_consumer_jank
  FROM app_frames
),
-- JANK_TYPE_DISPLAY_DEDUP_CTES_BEGIN
ranked_jank_rows AS (
  SELECT
    *,
    MAX(row_is_consumer_jank) OVER (PARTITION BY frame_key) as is_consumer_jank,
    ROW_NUMBER() OVER (
      PARTITION BY frame_key
      ORDER BY
        row_is_consumer_jank DESC,
        CASE
          WHEN jank_type GLOB '*Self Jank*' OR android_is_app_jank_type(jank_type) THEN 1
          WHEN jank_type GLOB '*SurfaceFlinger*' THEN 2
          WHEN jank_type GLOB '*Buffer Stuffing*' THEN 3
          WHEN android_is_sf_jank_type(jank_type) THEN 4
          WHEN jank_type != 'None' THEN 5
          ELSE 6
        END,
        dur DESC,
        layer_name ASC
    ) as frame_row_rank
  FROM jank_row_signals
),
jank_analysis AS (
  SELECT frame_key, jank_type, dur, is_consumer_jank
  FROM ranked_jank_rows
  WHERE frame_row_rank = 1
)
-- JANK_TYPE_DISPLAY_DEDUP_CTES_END
SELECT
  jank_type,
  COUNT(*) as count,
  -- 实际用户感知掉帧数（present_type 为 Late/Dropped）
  SUM(is_consumer_jank) as real_jank_count,
  -- 假阳性数（jank_type 报告掉帧，但 present_type 未标记为 Late/Dropped）
  SUM(CASE WHEN jank_type != 'None' AND is_consumer_jank = 0 THEN 1 ELSE 0 END) as false_positive,
  CAST(SUM(CASE WHEN dur > 0 THEN dur ELSE 0 END) AS REAL) as total_dur,
  CAST(ROUND(AVG(CASE WHEN dur > 0 THEN dur ELSE NULL END)) AS INTEGER) as avg_dur,
  CASE
    WHEN jank_type GLOB '*Self Jank*' OR android_is_app_jank_type(jank_type) THEN '标签:App'
    WHEN jank_type GLOB '*SurfaceFlinger*' THEN '标签:SurfaceFlinger'
    WHEN jank_type GLOB '*Buffer Stuffing*' THEN '标签:Buffer Stuffing(需验证)'
    WHEN android_is_sf_jank_type(jank_type) THEN '标签:SurfaceFlinger'
    WHEN jank_type = 'None' THEN '标签:None(可能漏检)'
    ELSE '标签:Other'
  END as responsibility,
  '${buffer_tx_coverage.data[0].coverage_status}' as frame_timeline_coverage_status,
  ${buffer_tx_coverage.data[0].frame_timeline_to_buffer_tx_ratio} as frame_timeline_to_buffer_tx_ratio,
  CASE
    WHEN '${buffer_tx_coverage.data[0].coverage_status}' = 'partial_frame_timeline_coverage'
      THEN 'partial_sample'
    WHEN '${buffer_tx_coverage.data[0].coverage_status}' = 'no_buffer_tx_candidate'
      THEN 'frame_timeline_only_unbenchmarked'
    ELSE 'full_frame_timeline'
  END as evidence_scope
FROM jank_analysis
GROUP BY jank_type
ORDER BY real_jank_count DESC, count DESC
LIMIT 10
