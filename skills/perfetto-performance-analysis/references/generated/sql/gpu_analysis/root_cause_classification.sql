-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: 1782c39f5ca4ce044bf815ac7ed529e2509316b08ab38f26baaab7ce64fce6bb

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- No input CTE. The GPU frequency of every GPU as leading intervals, one row
-- per counter sample of the trace_processor "gpufreq" track (the same input
-- and interval shape as stdlib android_gpu_frequency, which returns the raw
-- value), with the value normalized to MHz.
--
-- That track is labelled kHz, but its writers disagree: power/gpu_frequency
-- and generic GPU events write kHz, kgsl_gpu_frequency is multiplied to Hz by
-- trace_processor, and sys_stats gpufreq_mhz writes MHz to GPU 0, so one
-- track can carry two units. Each sample is read by its own magnitude, which
-- is unambiguous for a GPU clock between 10 MHz and 10 GHz:
--   0                  off: the GPU is powered down, not running slowly
--   10 <= v < 1e4      MHz
--   1e4 <= v < 1e7     kHz
--   1e7 <= v <= 1e10   Hz
--   anything else      out_of_domain, freq_mhz NULL
-- prev_freq_mhz is the normalized previous value, so a unit change is not
-- a frequency change. A consumer reports off time apart and
-- leaves it out of averages and low-frequency shares.
gpu_frequency_samples AS (
  SELECT
    c.id AS counter_id,
    c.ts,
    c.track_id,
    t.ugpu,
    t.gpu_id,
    c.value AS raw_value,
    CASE
      WHEN c.value = 0 THEN 'off'
      WHEN c.value >= 10 AND c.value < 1e4 THEN 'mhz'
      WHEN c.value >= 1e4 AND c.value < 1e7 THEN 'khz'
      WHEN c.value >= 1e7 AND c.value <= 1e10 THEN 'hz'
      ELSE 'out_of_domain'
    END AS unit_basis
  FROM counter c
  JOIN gpu_counter_track t ON t.id = c.track_id
  WHERE t.name = 'gpufreq' AND t.gpu_id IS NOT NULL
),
gpu_frequency_normalized AS (
  SELECT
    *,
    CASE unit_basis
      WHEN 'off' THEN 0.0
      WHEN 'mhz' THEN raw_value
      WHEN 'khz' THEN raw_value / 1e3
      WHEN 'hz' THEN raw_value / 1e6
    END AS freq_mhz
  FROM gpu_frequency_samples
),
gpu_frequency_intervals AS (
  SELECT
    counter_id,
    ts,
    COALESCE(LEAD(ts) OVER w, trace_end()) - ts AS dur,
    track_id,
    ugpu,
    gpu_id,
    freq_mhz,
    unit_basis = 'off' AS is_off,
    unit_basis,
    LAG(freq_mhz) OVER w AS prev_freq_mhz
  FROM gpu_frequency_normalized
  WINDOW w AS (PARTITION BY track_id ORDER BY ts, counter_id)
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: fragments/gpu_frequency_intervals.sql, listed before this fragment;
-- the step parameters start_ts and end_ts (either may be NULL). The GPU
-- frequency intervals that overlap [start_ts, end_ts), clipped to it, so a
-- level held from before the window counts only for its time inside.
-- running_mhz is the frequency while the GPU runs (NULL when off or
-- unreadable). is_running_change marks a change between two running
-- frequencies whose sample was taken inside the window.
gpu_frequency_window AS (
  SELECT
    counter_id,
    ugpu,
    gpu_id,
    freq_mhz,
    is_off,
    prev_freq_mhz,
    CASE WHEN freq_mhz > 0 THEN freq_mhz END AS running_mhz,
    COALESCE((${start_ts} IS NULL OR ts >= ${start_ts}) AND freq_mhz > 0
      AND prev_freq_mhz > 0 AND freq_mhz != prev_freq_mhz, 0) AS is_running_change,
    MAX(ts, COALESCE(${start_ts}, ts)) AS ts,
    MIN(ts + dur, COALESCE(${end_ts}, ts + dur)) - MAX(ts, COALESCE(${start_ts}, ts)) AS dur
  FROM gpu_frequency_intervals
  WHERE dur > 0
    AND (${start_ts} IS NULL OR ${end_ts} IS NULL OR ${start_ts} < ${end_ts})
    AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: fragments/gpu_frequency_intervals.sql and
-- fragments/gpu_frequency_window.sql, listed before this fragment. One row
-- per GPU over the window: observed time split into running, off and
-- out-of-domain time, and the running frequencies (MHz) weighted by time.
-- A share of running time and a share of observed time are different
-- numbers; a consumer names which one it reports.
gpu_frequency_summary AS (
  SELECT
    gpu_id,
    SUM(dur) AS observed_ns,
    SUM(CASE WHEN running_mhz IS NOT NULL THEN dur ELSE 0 END) AS running_ns,
    SUM(CASE WHEN is_off THEN dur ELSE 0 END) AS off_ns,
    SUM(CASE WHEN freq_mhz IS NULL THEN dur ELSE 0 END) AS out_of_domain_ns,
    SUM(running_mhz * dur) / NULLIF(SUM(CASE WHEN running_mhz IS NOT NULL THEN dur END), 0) AS avg_running_mhz,
    MAX(running_mhz) AS max_running_mhz,
    MIN(running_mhz) AS min_running_mhz,
    COUNT(DISTINCT running_mhz) AS running_levels,
    SUM(is_running_change) AS running_change_count
  FROM gpu_frequency_window
  GROUP BY gpu_id
)
,
-- Per GPU, as shares of all observed time: at the top running
-- frequency, at 90% of it or above, running at 30% of it or below, and
-- powered off. An off GPU is idle, not slow, so GPU_IDLE reads low
-- running time and off time together and the evidence names each.
per_gpu AS (
  SELECT
    w.gpu_id,
    ROUND(100.0 * SUM(CASE WHEN w.running_mhz = s.max_running_mhz THEN w.dur ELSE 0 END) / NULLIF(s.observed_ns, 0), 1) as max_freq_pct,
    ROUND(100.0 * SUM(CASE WHEN w.running_mhz >= s.max_running_mhz * 0.9 THEN w.dur ELSE 0 END) / NULLIF(s.observed_ns, 0), 1) as high_freq_pct,
    ROUND(100.0 * SUM(CASE WHEN w.running_mhz <= s.max_running_mhz * 0.3 THEN w.dur ELSE 0 END) / NULLIF(s.observed_ns, 0), 1) as low_running_pct,
    ROUND(100.0 * s.off_ns / NULLIF(s.observed_ns, 0), 1) as off_pct,
    -- A drop of more than 30% between two running frequencies.
    SUM(w.is_running_change AND w.running_mhz < w.prev_freq_mhz * ${freq_drop_ratio|0.7}) as drop_count
  FROM gpu_frequency_window w
  JOIN gpu_frequency_summary s USING (gpu_id)
  GROUP BY w.gpu_id
),
-- The most loaded GPU decides.
busiest_gpu AS (
  SELECT * FROM per_gpu ORDER BY high_freq_pct DESC, gpu_id LIMIT 1
),
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
    COALESCE((SELECT max_freq_pct FROM busiest_gpu), 0) as max_freq_pct,
    COALESCE((SELECT high_freq_pct FROM busiest_gpu), 0) as high_freq_pct,
    COALESCE((SELECT low_running_pct FROM busiest_gpu), 0) as low_running_pct,
    COALESCE((SELECT off_pct FROM busiest_gpu), 0) as off_pct,
    COALESCE((SELECT drop_count FROM busiest_gpu), 0) as freq_drop_count,
    COALESCE((SELECT gpu_jank_frames FROM frame_stats), 0) as gpu_jank_frames,
    COALESCE((SELECT total_frames FROM frame_stats), 0) as total_frames
),
-- One classification; every column below follows it, so they cannot drift apart.
verdict AS (
  SELECT a.*,
    CASE
      WHEN high_freq_pct > ${high_freq_threshold_pct|70} THEN 'GPU_BOUND'
      WHEN freq_drop_count > ${freq_drop_count_threshold|20} AND high_freq_pct > 30 THEN 'GPU_FREQ_DROPS'
      WHEN low_running_pct + off_pct > ${high_freq_threshold_pct|70} THEN 'GPU_IDLE'
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
      'GPU 空闲: 低频运行占观测时间 ' || low_running_pct || '%、关闭占 ' || off_pct || '%，GPU 负载极低'
    WHEN 'GPU_JANK_RELATED' THEN
      'GPU 相关掉帧: 检测到 ' || gpu_jank_frames || ' 帧 GPU 相关 Jank'
    ELSE
      'GPU 状态正常，频率分布合理'
  END as root_cause_summary,
  '[' ||
    '"最高频占比: ' || max_freq_pct || '%",' ||
    '"高频区间占比: ' || high_freq_pct || '%",' ||
    '"低频运行占观测时间: ' || low_running_pct || '%",' ||
    '"GPU 关闭占比: ' || off_pct || '%",' ||
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
