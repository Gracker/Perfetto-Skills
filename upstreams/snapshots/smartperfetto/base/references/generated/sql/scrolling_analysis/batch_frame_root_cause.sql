-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

-- 批量帧根因分类：对所有消费端真实掉帧执行简化版根因决策树
-- 与 jank_frame_detail 的 root_cause_summary 使用相同优先级 CASE 树
-- 区别：jank_frame_detail 是单帧深钻，此步骤是全帧一次性分类
WITH
-- ========== 1. VSync 配置 ==========
vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
timing_config AS (
  SELECT
    vsync_period_ns,
    ROUND(vsync_period_ns / 1e6, 2) as frame_budget_ms,
    ROUND(vsync_period_ns / 1e6 * 0.50, 2) as slice_critical_ms,
    ROUND(MAX(vsync_period_ns / 1e6 * 0.35, 2.0), 2) as freq_ramp_critical_ms,
    ROUND(MAX(vsync_period_ns / 1e6 * 0.18, 1.5), 2) as binder_overlap_critical_ms
  FROM (
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
  )
),
-- ========== 1b. 设备峰值频率（全 trace 大核最高频率，用于温控/限频检测）==========
-- 不加 start_ts/end_ts 过滤 — 求设备硬件频率上限
-- 用 MAX — P95 会被大量空闲低频样本主导（CPU 大部分时间低频运行）
-- 优先级已从 P0.6 下调到 P4.5，配合 60% 阈值足以防止误判
device_peak_freq AS (
  SELECT COALESCE(ROUND(MAX(c.value) / 1000, 0), 0) as device_peak_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id AND cct.name = 'cpufreq'
  LEFT JOIN _cpu_topology ct ON cct.cpu = ct.cpu_id
  WHERE ct.core_type IN ('prime', 'big')
),
-- ========== 2. Per-layer 帧序列 + 双信号混合掉帧检测（与 get_app_jank_frames 一致）==========
layer_frames AS (
  SELECT
    COALESCE(a.display_frame_token, a.surface_frame_token) as display_frame_token,
    a.surface_frame_token as surface_frame_token,
    CASE WHEN a.name GLOB '[0-9]*' THEN CAST(a.name AS INTEGER) ELSE NULL END as timeline_frame_id,
    a.ts as frame_start,
    a.ts + a.dur as frame_end,
    a.dur as frame_dur,
    a.jank_type,
    COALESCE(a.present_type, 'Unknown Present') as present_type,
    a.upid,
    a.layer_name,
    COALESCE(a.display_frame_token, a.surface_frame_token) - LAG(COALESCE(a.display_frame_token, a.surface_frame_token))
      OVER (PARTITION BY a.layer_name ORDER BY COALESCE(a.display_frame_token, a.surface_frame_token)) AS token_gap,
    a.ts - LAG(a.ts + a.dur)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts) AS time_gap_ns,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END AS present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts) AS prev_present_ts
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
session_markers AS (
  SELECT *,
    CASE WHEN time_gap_ns IS NULL OR time_gap_ns > (SELECT vsync_period_ns * 6 FROM timing_config) THEN 1 ELSE 0 END as new_session
  FROM layer_frames
),
sessions_map AS (
  SELECT *,
    SUM(new_session) OVER (PARTITION BY layer_name ORDER BY frame_start) as session_id
  FROM session_markers
),
-- 掉帧检测：双信号混合策略（与 jank_frames 保持一致）
all_jank_frames AS (
  SELECT
    sm.display_frame_token,
    sm.surface_frame_token,
    sm.timeline_frame_id,
    sm.frame_start,
    sm.frame_end,
    sm.frame_dur,
    sm.jank_type,
    sm.upid,
    sm.session_id,
    p.pid,
    p.name as process_name,
    ROUND(sm.frame_dur / 1e6, 2) as dur_ms,
    CASE
      WHEN sm.jank_type IN ('Self Jank', 'App Deadline Missed', 'App Resynced Jitter') THEN 'APP'
      WHEN sm.jank_type GLOB '*SurfaceFlinger*' THEN 'SF'
      WHEN sm.jank_type = 'Buffer Stuffing' THEN 'BUFFER_STUFFING'
      WHEN sm.jank_type = 'None' OR sm.jank_type IS NULL THEN 'HIDDEN'
      ELSE 'UNKNOWN'
    END as jank_responsibility,
    CASE
      WHEN sm.prev_present_ts IS NOT NULL AND sm.present_ts - sm.prev_present_ts > tc.vsync_period_ns * 1.5
        THEN MAX(CAST(ROUND((sm.present_ts - sm.prev_present_ts) * 1.0 / tc.vsync_period_ns - 1, 0) AS INTEGER), 0)
      ELSE 1  -- at least 1 vsync missed if present_type is Late/Dropped
    END as vsync_missed,
    CASE
      WHEN sm.prev_present_ts IS NOT NULL
        THEN ROUND((sm.present_ts - sm.prev_present_ts) / 1e6, 2)
      ELSE NULL
    END as present_interval_ms
  FROM sessions_map sm
  CROSS JOIN timing_config tc
  JOIN process p ON sm.upid = p.upid
  WHERE (
    -- 非 BS：present_type 为权威信号
    (sm.present_type IN ('Late Present', 'Dropped Frame') AND (sm.jank_type IS NULL OR sm.jank_type != 'Buffer Stuffing'))
    OR
    -- BS + 异常间隔：真实掉帧被 BS 掩盖
    (sm.jank_type = 'Buffer Stuffing'
     AND sm.prev_present_ts IS NOT NULL
     AND (sm.present_ts - sm.prev_present_ts) > tc.vsync_period_ns * 1.5
     AND (sm.present_ts - sm.prev_present_ts) <= tc.vsync_period_ns * 6)
  )
  -- 排除会话间断帧
  AND (sm.time_gap_ns IS NULL OR sm.time_gap_ns <= tc.vsync_period_ns * 6)
),
-- 按严重度排序（与 get_app_jank_frames 完全一致的 rank_in_session 逻辑）
ranked_jank_frames AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY vsync_missed DESC, frame_dur DESC) as rank_in_session
  FROM all_jank_frames
),
-- 截断后重新编号（与 get_app_jank_frames 的 frame_index 完全对齐）
jank_frame_list AS (
  SELECT
    display_frame_token, surface_frame_token, timeline_frame_id, frame_start, frame_end, frame_dur, jank_type, upid, session_id,
    pid, process_name, dur_ms, jank_responsibility, vsync_missed, present_interval_ms,
    ROW_NUMBER() OVER (ORDER BY session_id, frame_start) as frame_index
  FROM ranked_jank_frames
  WHERE rank_in_session <= CASE
    WHEN ${max_frames_per_session} IS NULL THEN 200
    WHEN CAST(${max_frames_per_session} AS INTEGER) <= 0 THEN 200
    ELSE CAST(${max_frames_per_session} AS INTEGER)
  END
),
-- ========== 3. Explicit role-based thread identification ==========
-- Main thread:   t.tid = p.pid (standard Android) OR t.name GLOB '*.ui' (Flutter)
-- RenderThread:  t.name = 'RenderThread' (standard Android) OR t.name GLOB '*.raster' (Flutter)
-- Aligned with the jank_frame_detail.skill.yaml proven approach.
per_frame_thread_roles AS (
  SELECT
    fl.frame_start,
    t.utid,
    t.tid,
    t.name as thread_name,
    CASE
      WHEN t.tid = p.pid THEN 'main'
      WHEN t.name GLOB '[0-9]*.ui' THEN 'main'
      WHEN t.name = 'RenderThread' THEN 'render'
      WHEN t.name GLOB '[0-9]*.raster' THEN 'render'
    END as role
  FROM jank_frame_list fl
  JOIN process p ON fl.upid = p.upid
  JOIN thread t ON t.upid = fl.upid
  WHERE t.tid = p.pid
    OR t.name = 'RenderThread'
    OR t.name GLOB '[0-9]*.ui'
    OR t.name GLOB '[0-9]*.raster'
),
-- ========== 4. Per-frame: 最耗时 producer 线程 slice ==========
-- Choreographer#doFrame - resynced... is a child marker showing
-- frame-timeline resynchronization; exclude it from workload ranking.
frame_slices AS (
  SELECT
    fl.frame_start,
    s.name as slice_name,
    s.ts as slice_ts,
    s.dur as slice_dur_ns,
    ROUND(s.dur / 1e6, 2) as slice_dur_ms,
    ROUND((s.ts - fl.frame_start) / 1e6, 2) as slice_offset_ms,
    ROW_NUMBER() OVER (PARTITION BY fl.frame_start ORDER BY s.dur DESC) as rn
  FROM jank_frame_list fl
  JOIN per_frame_thread_roles ptr ON ptr.frame_start = fl.frame_start AND ptr.role = 'main'
  JOIN thread_track tt ON tt.utid = ptr.utid
  JOIN slice s ON s.track_id = tt.id
    AND s.ts >= fl.frame_start - 5000000
    AND s.ts < fl.frame_end
    AND s.dur >= 1000000
    AND s.name NOT GLOB '*resynced*'
),
top_slices AS (
  SELECT * FROM frame_slices WHERE rn = 1
),
-- ========== 5. Per-frame top slice: 核心类型 + 调度分析 ==========
top_slice_states AS (
  SELECT
    ts_top.frame_start,
    tst.state,
    COALESCE(ct.core_type, 'unknown') as core_type,
    (MIN(tst.ts + tst.dur, ts_top.slice_ts + ts_top.slice_dur_ns) - MAX(tst.ts, ts_top.slice_ts)) as overlap_ns
  FROM top_slices ts_top
  JOIN per_frame_thread_roles ptr ON ptr.frame_start = ts_top.frame_start AND ptr.role = 'main'
  JOIN thread_state tst ON tst.utid = ptr.utid
    AND tst.ts < ts_top.slice_ts + ts_top.slice_dur_ns
    AND tst.ts + tst.dur > ts_top.slice_ts
  LEFT JOIN _cpu_topology ct ON tst.cpu = ct.cpu_id
),
per_frame_cpu_mix AS (
  SELECT
    frame_start,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('medium', 'little') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as little_run_pct,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as big_run_pct,
    ROUND(100.0 * SUM(CASE WHEN state = 'R' AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as runnable_pct
  FROM top_slice_states
  GROUP BY frame_start
),
-- ========== 6. Per-frame: 主线程四象限 ==========
frame_thread_states AS (
  SELECT
    fl.frame_start,
    tst.state,
    COALESCE(ct.core_type, 'unknown') as core_type,
    (MIN(tst.ts + tst.dur, fl.frame_end) - MAX(tst.ts, fl.frame_start)) as overlap_ns
  FROM jank_frame_list fl
  JOIN per_frame_thread_roles ptr ON ptr.frame_start = fl.frame_start AND ptr.role = 'main'
  JOIN thread_state tst ON tst.utid = ptr.utid
    AND tst.ts < fl.frame_end
    AND tst.ts + tst.dur > fl.frame_start
  LEFT JOIN _cpu_topology ct ON tst.cpu = ct.cpu_id
),
per_frame_quadrants AS (
  SELECT
    frame_start,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as q1_pct,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('medium', 'little') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as q2_pct,
    ROUND(100.0 * SUM(CASE WHEN state = 'R' AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as q3_pct,
    ROUND(100.0 * SUM(CASE WHEN state IN ('D', 'DK') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as q4a_pct,
    ROUND(100.0 * SUM(CASE WHEN state IN ('S', 'I') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as q4b_pct
  FROM frame_thread_states
  GROUP BY frame_start
),
-- ========== 6b. Per-frame: 渲染线程四象限 ==========
render_thread_states AS (
  SELECT
    fl.frame_start,
    tst.state,
    COALESCE(ct.core_type, 'unknown') as core_type,
    (MIN(tst.ts + tst.dur, fl.frame_end) - MAX(tst.ts, fl.frame_start)) as overlap_ns
  FROM jank_frame_list fl
  JOIN per_frame_thread_roles ptr ON ptr.frame_start = fl.frame_start AND ptr.role = 'render'
  JOIN thread_state tst ON tst.utid = ptr.utid
    AND tst.ts < fl.frame_end
    AND tst.ts + tst.dur > fl.frame_start
  LEFT JOIN _cpu_topology ct ON tst.cpu = ct.cpu_id
),
render_thread_quadrants AS (
  SELECT
    frame_start,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as render_q1_pct,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('medium', 'little') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as render_q2_pct,
    ROUND(100.0 * SUM(CASE WHEN state = 'R' AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as render_q3_pct,
    ROUND(100.0 * SUM(CASE WHEN state IN ('D', 'DK') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as render_q4a_pct,
    ROUND(100.0 * SUM(CASE WHEN state IN ('S', 'I') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as render_q4b_pct
  FROM render_thread_states
  GROUP BY frame_start
),
-- ========== 7. Per-frame: 大核频率 ==========
per_frame_freq AS (
  SELECT
    fl.frame_start,
    ROUND(AVG(c.value) / 1000, 0) as big_avg_freq_mhz,
    ROUND(MAX(c.value) / 1000, 0) as big_max_freq_mhz
  FROM jank_frame_list fl
  JOIN counter c ON c.ts >= fl.frame_start AND c.ts < fl.frame_end
  JOIN cpu_counter_track cct ON c.track_id = cct.id AND cct.name = 'cpufreq'
  LEFT JOIN _cpu_topology ct ON cct.cpu = ct.cpu_id
  WHERE ct.core_type IN ('prime', 'big')
  GROUP BY fl.frame_start
),
-- ========== 8. Per-frame: 频率爬升延迟 ==========
frame_peak_freq AS (
  SELECT fl.frame_start, MAX(c.value) as peak_khz
  FROM jank_frame_list fl
  JOIN counter c ON c.ts >= fl.frame_start AND c.ts < fl.frame_end
  JOIN cpu_counter_track cct ON c.track_id = cct.id AND cct.name = 'cpufreq'
  LEFT JOIN _cpu_topology ct ON cct.cpu = ct.cpu_id
  WHERE ct.core_type IN ('prime', 'big')
  GROUP BY fl.frame_start
),
per_frame_ramp AS (
  SELECT
    fl.frame_start,
    ROUND(
      (COALESCE(
        MIN(CASE WHEN c.value >= CASE WHEN fpf.peak_khz * 0.70 > 1800000 THEN fpf.peak_khz * 0.70 ELSE 1800000 END THEN c.ts END),
        fl.frame_end
      ) - fl.frame_start) / 1e6, 2
    ) as ramp_to_high_ms
  FROM jank_frame_list fl
  JOIN frame_peak_freq fpf ON fpf.frame_start = fl.frame_start
  JOIN counter c ON c.ts >= fl.frame_start AND c.ts < fl.frame_end
  JOIN cpu_counter_track cct ON c.track_id = cct.id AND cct.name = 'cpufreq'
  LEFT JOIN _cpu_topology ct ON cct.cpu = ct.cpu_id
  WHERE ct.core_type IN ('prime', 'big')
  GROUP BY fl.frame_start
),
-- ========== 9. Per-frame: Binder 同步与 top slice 重叠 ==========
per_frame_binder AS (
  SELECT
    ts_top.frame_start,
    ROUND(COALESCE(SUM(
      CASE
        WHEN bt.client_ts < ts_top.slice_ts + ts_top.slice_dur_ns
          AND bt.client_ts + bt.client_dur > ts_top.slice_ts
        THEN (
          MIN(bt.client_ts + bt.client_dur, ts_top.slice_ts + ts_top.slice_dur_ns) -
          MAX(bt.client_ts, ts_top.slice_ts)
        )
        ELSE 0
      END
    ), 0) / 1e6, 2) as binder_overlap_ms
  FROM top_slices ts_top
  JOIN per_frame_thread_roles ptr ON ptr.frame_start = ts_top.frame_start AND ptr.role = 'main'
  LEFT JOIN android_binder_txns bt ON bt.client_tid = ptr.tid
    AND bt.is_sync = 1
    AND bt.client_ts < ts_top.slice_ts + ts_top.slice_dur_ns
    AND bt.client_ts + bt.client_dur > ts_top.slice_ts
  GROUP BY ts_top.frame_start
),
-- ========== 9.5. Per-frame: GPU fence 等待检测 ==========
gpu_fence_per_frame AS (
  SELECT
    fl.frame_start,
    MAX(CASE WHEN s.name GLOB '*Fence*' OR s.name GLOB '*fence*' OR s.name GLOB '*eglSwapBuffers*' OR s.name GLOB '*dequeueBuffer*'
         THEN s.dur ELSE 0 END) as max_fence_dur_ns,
    SUM(CASE WHEN s.name GLOB '*Fence*' OR s.name GLOB '*fence*' OR s.name GLOB '*eglSwapBuffers*' OR s.name GLOB '*dequeueBuffer*'
         THEN s.dur ELSE 0 END) as total_fence_dur_ns
  FROM jank_frame_list fl
  JOIN slice s ON s.ts >= fl.frame_start AND s.ts < fl.frame_end
  JOIN thread_track tk ON s.track_id = tk.id
  JOIN thread t ON tk.utid = t.utid
  WHERE t.upid = fl.upid  -- same process only (no thread name filter needed)
  GROUP BY fl.frame_start
),
-- ========== 9.6. Per-frame: Shader compilation 检测 ==========
shader_per_frame AS (
  SELECT
    fl.frame_start,
    COUNT(*) as shader_count,
    SUM(s.dur) as total_shader_dur_ns
  FROM jank_frame_list fl
  JOIN slice s ON s.ts >= fl.frame_start AND s.ts < fl.frame_end
  JOIN thread_track tk ON s.track_id = tk.id
  JOIN thread t ON tk.utid = t.utid
  WHERE t.upid = fl.upid  -- same process only (no thread name filter needed)
    AND (s.name GLOB '*shader*' OR s.name GLOB '*Shader*' OR s.name GLOB '*compile*' OR s.name GLOB '*Compile*')
  GROUP BY fl.frame_start
),
-- ========== 9.7. Per-frame: GC 事件与帧窗口重叠 ==========
per_frame_gc AS (
  SELECT
    fl.frame_start,
    ROUND(COALESCE(SUM(
      MIN(gc.gc_ts + gc.gc_dur, fl.frame_end) - MAX(gc.gc_ts, fl.frame_start)
    ), 0) / 1e6, 2) as gc_overlap_ms,
    COUNT(gc.gc_ts) as gc_count
  FROM jank_frame_list fl
  LEFT JOIN (
    SELECT gc.gc_ts, gc.gc_dur
    FROM android_garbage_collection_events gc
    JOIN thread t ON gc.tid = t.tid
    JOIN process p ON t.upid = p.upid
    WHERE (p.name GLOB '${package}*' OR '${package}' = '')
  ) gc ON gc.gc_ts < fl.frame_end AND gc.gc_ts + gc.gc_dur > fl.frame_start
  GROUP BY fl.frame_start
),
-- ========== 10. 批量详情 JSON 列（覆盖全部掉帧，避免 N+1 查询） ==========
-- 10a. 全簇 CPU 频率 (prime/big/little)
per_frame_cpu_clusters AS (
  SELECT frame_start,
    json_group_array(json_object(
      'core_type', core_type,
      'avg_mhz', avg_mhz,
      'max_mhz', max_mhz,
      'min_mhz', min_mhz
    )) as cpu_freq_clusters_json
  FROM (
    SELECT
      fl.frame_start,
      COALESCE(ct.core_type, 'unknown') as core_type,
      CAST(ROUND(AVG(c.value) / 1000, 0) AS INTEGER) as avg_mhz,
      CAST(ROUND(MAX(c.value) / 1000, 0) AS INTEGER) as max_mhz,
      CAST(ROUND(MIN(c.value) / 1000, 0) AS INTEGER) as min_mhz
    FROM jank_frame_list fl
    JOIN counter c ON c.ts >= fl.frame_start AND c.ts < fl.frame_end
    JOIN cpu_counter_track cct ON c.track_id = cct.id AND cct.name = 'cpufreq'
    LEFT JOIN _cpu_topology ct ON cct.cpu = ct.cpu_id
    GROUP BY fl.frame_start, COALESCE(ct.core_type, 'unknown')
  )
  GROUP BY frame_start
),
-- 10b. 各 CPU 频率变化时间线（频率单位 GHz）
per_frame_freq_changes AS (
  SELECT frame_start,
    json_group_array(json_object(
      'relative_ms', relative_ms,
      'cpu', cpu,
      'core_type', core_type,
      'freq_ghz', freq_ghz,
      'change', change_dir
    )) as freq_timeline_json
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (PARTITION BY frame_start ORDER BY relative_ms, cpu) as rn
    FROM (
      SELECT
        fl.frame_start,
        ROUND((c.ts - fl.frame_start) / 1e6, 2) as relative_ms,
        cct.cpu,
        COALESCE(ct.core_type, 'unknown') as core_type,
        ROUND(c.value / 1e6, 2) as freq_ghz,
        c.value as freq_khz,
        LAG(c.value) OVER (PARTITION BY fl.frame_start, cct.cpu ORDER BY c.ts) as prev_freq_khz,
        CASE
          WHEN c.value > COALESCE(LAG(c.value) OVER (PARTITION BY fl.frame_start, cct.cpu ORDER BY c.ts), c.value) THEN 'up'
          WHEN c.value < COALESCE(LAG(c.value) OVER (PARTITION BY fl.frame_start, cct.cpu ORDER BY c.ts), c.value) THEN 'down'
          ELSE 'stable'
        END as change_dir
      FROM jank_frame_list fl
      JOIN counter c ON c.ts >= fl.frame_start AND c.ts < fl.frame_end
      JOIN cpu_counter_track cct ON c.track_id = cct.id AND cct.name = 'cpufreq'
      LEFT JOIN _cpu_topology ct ON cct.cpu = ct.cpu_id
    )
    WHERE freq_khz != COALESCE(prev_freq_khz, 0)
  )
  WHERE rn <= 30
  GROUP BY frame_start
),
-- 10c. 主线程 Top 8 耗时 Slice
-- Keep resync markers out of generic main-thread workload slices.
per_frame_main_top_slices AS (
  SELECT frame_start,
    json_group_array(json_object(
      'name', slice_name,
      'total_ms', dur_ms,
      'count', cnt,
      'max_ms', max_ms,
      'ts', ts_str
    )) as main_slices_json
  FROM (
    SELECT
      fl.frame_start,
      s.name as slice_name,
      ROUND(SUM(s.dur) / 1e6, 2) as dur_ms,
      COUNT(*) as cnt,
      ROUND(MAX(s.dur) / 1e6, 2) as max_ms,
      printf('%d', MIN(s.ts)) as ts_str,
      ROW_NUMBER() OVER (PARTITION BY fl.frame_start ORDER BY SUM(s.dur) DESC) as rn
    FROM jank_frame_list fl
    JOIN per_frame_thread_roles ptr ON ptr.frame_start = fl.frame_start AND ptr.role = 'main'
    JOIN thread_track tt ON tt.utid = ptr.utid
    JOIN slice s ON s.track_id = tt.id
      AND s.ts >= fl.frame_start - 5000000
      AND s.ts < fl.frame_end
      AND s.dur >= 500000
      AND s.name NOT GLOB '*resynced*'
    GROUP BY fl.frame_start, s.name
    HAVING dur_ms > 0.5
  )
  WHERE rn <= 8
  GROUP BY frame_start
),
-- 10d. RenderThread Top 8 耗时 Slice
per_frame_render_top_slices AS (
  SELECT frame_start,
    json_group_array(json_object(
      'name', slice_name,
      'total_ms', dur_ms,
      'count', cnt,
      'max_ms', max_ms,
      'ts', ts_str
    )) as render_slices_json
  FROM (
    SELECT
      fl.frame_start,
      s.name as slice_name,
      ROUND(SUM(s.dur) / 1e6, 2) as dur_ms,
      COUNT(*) as cnt,
      ROUND(MAX(s.dur) / 1e6, 2) as max_ms,
      printf('%d', MIN(s.ts)) as ts_str,
      ROW_NUMBER() OVER (PARTITION BY fl.frame_start ORDER BY SUM(s.dur) DESC) as rn
    FROM jank_frame_list fl
    JOIN per_frame_thread_roles ptr ON ptr.frame_start = fl.frame_start AND ptr.role = 'render'
    JOIN thread_track tt ON tt.utid = ptr.utid
    JOIN slice s ON s.track_id = tt.id
      AND s.ts >= fl.frame_start - 5000000
      AND s.ts < fl.frame_end
      AND s.dur >= 500000
    GROUP BY fl.frame_start, s.name
    HAVING dur_ms > 0.5
  )
  WHERE rn <= 8
  GROUP BY frame_start
),
-- 10e. Binder 调用详情（按 server_process 聚合，Top 5）
per_frame_binder_detail AS (
  SELECT frame_start,
    json_group_array(json_object(
      'server', server_process,
      'count', cnt,
      'dur_ms', dur_ms,
      'max_ms', max_ms
    )) as binder_calls_json
  FROM (
    SELECT
      fl.frame_start,
      bt.server_process,
      COUNT(*) as cnt,
      ROUND(SUM(bt.client_dur) / 1e6, 2) as dur_ms,
      ROUND(MAX(bt.client_dur) / 1e6, 2) as max_ms,
      ROW_NUMBER() OVER (PARTITION BY fl.frame_start ORDER BY SUM(bt.client_dur) DESC) as rn
    FROM jank_frame_list fl
    JOIN per_frame_thread_roles ptr ON ptr.frame_start = fl.frame_start AND ptr.role = 'main'
    LEFT JOIN android_binder_txns bt ON bt.client_tid = ptr.tid
      AND bt.client_ts >= fl.frame_start
      AND bt.client_ts < fl.frame_end
    WHERE bt.server_process IS NOT NULL
    GROUP BY fl.frame_start, bt.server_process
    HAVING dur_ms > 0.1
  )
  WHERE rn <= 5
  GROUP BY frame_start
),
-- 10f. GC 事件详情（按类型聚合）
per_frame_gc_detail AS (
  SELECT frame_start,
    json_group_array(json_object(
      'gc_type', gc_type,
      'count', cnt,
      'total_ms', total_dur_ms,
      'overlap_ms', overlap_ms
    )) as gc_events_json
  FROM (
    SELECT
      fl.frame_start,
      COALESCE(gc.gc_type, 'unknown') as gc_type,
      COUNT(*) as cnt,
      ROUND(SUM(gc.gc_dur) / 1e6, 2) as total_dur_ms,
      ROUND(SUM(
        MAX(MIN(gc.gc_ts + gc.gc_dur, fl.frame_end) - MAX(gc.gc_ts, fl.frame_start), 0)
      ) / 1e6, 2) as overlap_ms
    FROM jank_frame_list fl
    LEFT JOIN (
      SELECT gc.gc_ts, gc.gc_dur, gc.gc_type, t.tid
      FROM android_garbage_collection_events gc
      JOIN thread t ON gc.tid = t.tid
      JOIN process p ON t.upid = p.upid
      WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    ) gc ON gc.gc_ts < fl.frame_end AND gc.gc_ts + gc.gc_dur > fl.frame_start
    WHERE gc.gc_ts IS NOT NULL
    GROUP BY fl.frame_start, COALESCE(gc.gc_type, 'unknown')
    HAVING overlap_ms > 0
  )
  GROUP BY frame_start
),
-- 10g. 锁竞争详情（Top 5，需要 android_monitor_contention 表）
per_frame_lock_detail AS (
  SELECT frame_start,
    json_group_array(json_object(
      'method', blocking_method,
      'blocker', blocking_thread_name,
      'wait_ms', wait_ms,
      'main_blocked', main_blocked
    )) as lock_contention_json
  FROM (
    SELECT
      fl.frame_start,
      amc.short_blocking_method as blocking_method,
      amc.blocking_thread_name,
      ROUND(amc.dur / 1e6, 2) as wait_ms,
      CASE WHEN amc.is_blocked_thread_main THEN 1 ELSE 0 END as main_blocked,
      ROW_NUMBER() OVER (PARTITION BY fl.frame_start ORDER BY amc.dur DESC) as rn
    FROM jank_frame_list fl
    JOIN android_monitor_contention amc ON amc.ts >= fl.frame_start AND amc.ts < fl.frame_end
      AND (amc.process_name GLOB '${package}*' OR '${package}' = '')
      AND amc.dur >= 200000
  )
  WHERE rn <= 5
  GROUP BY frame_start
),
-- 10h. 主线程文件 IO 检测（SharedPreferences/sqlite/fsync 等 IO slice 与帧窗口重叠）
per_frame_file_io AS (
  SELECT fl.frame_start,
    ROUND(SUM(
      MAX(MIN(s.ts + s.dur, fl.frame_end) - MAX(s.ts, fl.frame_start), 0)
    ) / 1e6, 2) as file_io_overlap_ms
  FROM jank_frame_list fl
  JOIN per_frame_thread_roles ptr ON ptr.frame_start = fl.frame_start AND ptr.role = 'main'
  JOIN thread_track tt ON tt.utid = ptr.utid
  JOIN slice s ON s.track_id = tt.id
    AND s.ts < fl.frame_end AND s.ts + s.dur > fl.frame_start
    AND s.dur > 500000
  WHERE s.name GLOB '*SharedPreferences*'
    OR s.name GLOB '*getSharedPreferences*'
    OR s.name GLOB '*commit*SharedPref*'
    OR s.name GLOB '*QueuedWork*'
    OR s.name GLOB '*waitToFinish*'
    OR s.name GLOB '*sqlite*'
    OR s.name GLOB '*SQLiteDatabase*'
    OR s.name GLOB '*openFile*'
    OR s.name GLOB '*fsync*'
  GROUP BY fl.frame_start
),
-- 10i. Input event 与帧关联（android.input stdlib，按 FrameTimeline name/frame_id 对齐）。
-- input_data_fallback_view 会在 stdlib 缺失时创建同 schema 空视图，因此本查询
-- 既能使用真实 input 事件，也不会破坏基础帧根因分析。
per_frame_input_events AS (
  SELECT
    fl.frame_start,
    COUNT(*) as input_event_count,
    SUM(CASE WHEN ie.event_action = 'MOVE' THEN 1 ELSE 0 END) as input_move_count,
    ROUND(MAX(ie.handling_latency_dur) / 1e6, 2) as input_handling_ms,
    ROUND(SUM(ie.handling_latency_dur) / 1e6, 2) as input_handling_total_ms,
    ROUND(MAX(ie.dispatch_latency_dur) / 1e6, 2) as input_dispatch_ms,
    ROUND(MAX(ie.ack_latency_dur) / 1e6, 2) as input_ack_ms,
    ROUND(MAX(ie.total_latency_dur) / 1e6, 2) as input_total_ms,
    ROUND(MAX(ie.end_to_end_latency_dur) / 1e6, 2) as input_e2e_ms,
    SUM(CASE WHEN ie.is_speculative_frame = 1 THEN 1 ELSE 0 END) as input_speculative_events
  FROM jank_frame_list fl
  JOIN android_input_events ie ON ie.upid = fl.upid
    AND fl.timeline_frame_id IS NOT NULL
    AND ie.frame_id = fl.timeline_frame_id
  GROUP BY fl.frame_start
),
-- 10j. Atrace-backed input stage slices overlapping the janky frame.
per_frame_input_stage_totals AS (
  SELECT
    fl.frame_start,
    CASE
      WHEN s.name GLOB '*deliverInputEvent*' THEN 'deliverInputEvent'
      WHEN s.name GLOB '*processInputEventForCompatibility*' THEN 'processInputEventForCompatibility'
      WHEN s.name GLOB '*dispatchTouchEvent*' THEN 'dispatchTouchEvent'
      WHEN s.name GLOB '*onInterceptTouchEvent*' THEN 'onInterceptTouchEvent'
      WHEN s.name GLOB '*onTouchEvent*' THEN 'onTouchEvent'
      WHEN s.name GLOB '*InputConsumer*' THEN 'InputConsumer'
      WHEN s.name GLOB '*RV Prefetch*' OR s.name GLOB '*RecyclerView*Prefetch*' THEN 'RecyclerView Prefetch'
      ELSE 'input'
    END as input_stage,
    ROUND(SUM(
      MAX(MIN(s.ts + s.dur, fl.frame_end) - MAX(s.ts, fl.frame_start), 0)
    ) / 1e6, 2) as input_slice_ms,
    COUNT(*) as input_slice_count,
    ROUND(MAX(s.dur) / 1e6, 2) as input_slice_max_ms
  FROM jank_frame_list fl
  JOIN per_frame_thread_roles ptr ON ptr.frame_start = fl.frame_start AND ptr.role = 'main'
  JOIN thread_track tt ON tt.utid = ptr.utid
  JOIN slice s ON s.track_id = tt.id
    AND s.ts < fl.frame_end
    AND s.ts + s.dur > fl.frame_start
    AND s.dur >= 100000
  WHERE s.name GLOB '*deliverInputEvent*'
    OR s.name GLOB '*processInputEventForCompatibility*'
    OR s.name GLOB '*dispatchTouchEvent*'
    OR s.name GLOB '*onInterceptTouchEvent*'
    OR s.name GLOB '*onTouchEvent*'
    OR s.name GLOB '*InputConsumer*'
    OR s.name GLOB '*RV Prefetch*'
    OR s.name GLOB '*RecyclerView*Prefetch*'
  GROUP BY fl.frame_start, input_stage
),
per_frame_input_slices AS (
  SELECT
    frame_start,
    input_stage,
    input_slice_ms,
    input_slice_count,
    input_slice_max_ms
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (PARTITION BY frame_start ORDER BY input_slice_ms DESC) as rn
    FROM per_frame_input_stage_totals
  )
  WHERE rn = 1
),
per_frame_input_detail AS (
  SELECT frame_start,
    json_group_array(json_object(
      'action', event_action,
      'channel', normalized_event_channel,
      'handling_ms', handling_ms,
      'dispatch_ms', dispatch_ms,
      'ack_ms', ack_ms,
      'total_ms', total_ms,
      'e2e_ms', e2e_ms,
      'speculative', speculative,
      'input_ts', input_ts
    )) as input_events_json
  FROM (
    SELECT
      fl.frame_start,
      ie.event_action,
      ie.normalized_event_channel,
      ROUND(ie.handling_latency_dur / 1e6, 2) as handling_ms,
      ROUND(ie.dispatch_latency_dur / 1e6, 2) as dispatch_ms,
      ROUND(ie.ack_latency_dur / 1e6, 2) as ack_ms,
      ROUND(ie.total_latency_dur / 1e6, 2) as total_ms,
      ROUND(ie.end_to_end_latency_dur / 1e6, 2) as e2e_ms,
      CASE WHEN ie.is_speculative_frame = 1 THEN 1 ELSE 0 END as speculative,
      printf('%d', ie.dispatch_ts) as input_ts,
      ROW_NUMBER() OVER (PARTITION BY fl.frame_start ORDER BY ie.handling_latency_dur DESC) as rn
    FROM jank_frame_list fl
    JOIN android_input_events ie ON ie.upid = fl.upid
      AND fl.timeline_frame_id IS NOT NULL
      AND ie.frame_id = fl.timeline_frame_id
  )
  WHERE rn <= 5
  GROUP BY frame_start
),
per_frame_input_slice_detail AS (
  SELECT frame_start,
    json_group_array(json_object(
      'stage', input_stage,
      'overlap_ms', input_slice_ms,
      'count', input_slice_count,
      'max_ms', input_slice_max_ms
    )) as input_slices_json
  FROM per_frame_input_stage_totals
  GROUP BY frame_start
),
-- ========== 11. 综合分析 ==========
analysis AS (
  SELECT
    fl.display_frame_token,
    fl.frame_start,
    fl.frame_end,
    fl.dur_ms,
    fl.jank_type,
    fl.jank_responsibility,
    fl.session_id,
    fl.pid,
    fl.process_name,
    fl.frame_index,
    fl.vsync_missed,
    fl.present_interval_ms,
    COALESCE(ts.slice_name, '') as top_slice_name,
    COALESCE(ts.slice_dur_ms, 0) as top_slice_ms,
    COALESCE(ts.slice_offset_ms, 0) as top_slice_offset_ms,
    COALESCE(pcm.little_run_pct, 0) as little_run_pct,
    COALESCE(pcm.big_run_pct, 0) as big_run_pct,
    COALESCE(pcm.runnable_pct, 0) as runnable_pct,
    COALESCE(pfq.q1_pct, 0) as main_q1_pct,
    COALESCE(pfq.q2_pct, 0) as main_q2_pct,
    COALESCE(pfq.q3_pct, 0) as main_q3_pct,
    COALESCE(pfq.q4a_pct, 0) as main_q4a_pct,
    COALESCE(pfq.q4b_pct, 0) as main_q4b_pct,
    COALESCE(rtq.render_q1_pct, 0) as render_q1_pct,
    COALESCE(rtq.render_q2_pct, 0) as render_q2_pct,
    COALESCE(rtq.render_q3_pct, 0) as render_q3_pct,
    COALESCE(rtq.render_q4a_pct, 0) as render_q4a_pct,
    COALESCE(rtq.render_q4b_pct, 0) as render_q4b_pct,
    COALESCE(pff.big_avg_freq_mhz, 0) as big_avg_freq_mhz,
    COALESCE(pff.big_max_freq_mhz, 0) as big_max_freq_mhz,
    COALESCE(pfr.ramp_to_high_ms, 0) as ramp_to_high_ms,
    COALESCE(pfb.binder_overlap_ms, 0) as binder_overlap_ms,
    COALESCE(pfgc.gc_overlap_ms, 0) as gc_overlap_ms,
    COALESCE(pfgc.gc_count, 0) as gc_count,
    COALESCE(gf.max_fence_dur_ns, 0) as max_fence_dur_ns,
    COALESCE(gf.total_fence_dur_ns, 0) as total_fence_dur_ns,
    COALESCE(sp.shader_count, 0) as shader_count,
    COALESCE(sp.total_shader_dur_ns, 0) as total_shader_dur_ns,
    tc.vsync_period_ns,
    tc.frame_budget_ms,
    tc.slice_critical_ms,
    tc.freq_ramp_critical_ms,
    tc.binder_overlap_critical_ms,
    COALESCE(pfcc.cpu_freq_clusters_json, '[]') as cpu_freq_clusters_json,
    COALESCE(pffc.freq_timeline_json, '[]') as freq_timeline_json,
    COALESCE(pfmts.main_slices_json, '[]') as main_slices_json,
    COALESCE(pfrts.render_slices_json, '[]') as render_slices_json,
    COALESCE(pfbd.binder_calls_json, '[]') as binder_calls_json,
    COALESCE(pfgd.gc_events_json, '[]') as gc_events_json,
    COALESCE(pfld.lock_contention_json, '[]') as lock_contention_json,
    COALESCE(pfio.file_io_overlap_ms, 0) as file_io_overlap_ms,
    COALESCE(pfie.input_event_count, 0) as input_event_count,
    COALESCE(pfie.input_move_count, 0) as input_move_count,
    COALESCE(pfie.input_handling_ms, pfis.input_slice_max_ms, 0) as input_handling_ms,
    COALESCE(pfie.input_handling_total_ms, pfis.input_slice_ms, 0) as input_handling_total_ms,
    COALESCE(pfie.input_dispatch_ms, 0) as input_dispatch_ms,
    COALESCE(pfie.input_ack_ms, 0) as input_ack_ms,
    COALESCE(pfie.input_total_ms, 0) as input_total_ms,
    COALESCE(pfie.input_e2e_ms, 0) as input_e2e_ms,
    COALESCE(pfie.input_speculative_events, 0) as input_speculative_events,
    COALESCE(pfis.input_slice_ms, 0) as input_slice_ms,
    COALESCE(pfis.input_slice_count, 0) as input_slice_count,
    COALESCE(pfis.input_slice_max_ms, 0) as input_slice_max_ms,
    COALESCE(pfis.input_stage, '') as input_stage,
    COALESCE(pfid.input_events_json, '[]') as input_events_json,
    COALESCE(pfisd.input_slices_json, '[]') as input_slices_json,
    dpf.device_peak_freq_mhz
  FROM jank_frame_list fl
  CROSS JOIN timing_config tc
  CROSS JOIN device_peak_freq dpf
  LEFT JOIN top_slices ts ON ts.frame_start = fl.frame_start
  LEFT JOIN per_frame_cpu_mix pcm ON pcm.frame_start = fl.frame_start
  LEFT JOIN per_frame_quadrants pfq ON pfq.frame_start = fl.frame_start
  LEFT JOIN render_thread_quadrants rtq ON rtq.frame_start = fl.frame_start
  LEFT JOIN per_frame_freq pff ON pff.frame_start = fl.frame_start
  LEFT JOIN per_frame_ramp pfr ON pfr.frame_start = fl.frame_start
  LEFT JOIN per_frame_binder pfb ON pfb.frame_start = fl.frame_start
  LEFT JOIN per_frame_gc pfgc ON pfgc.frame_start = fl.frame_start
  LEFT JOIN gpu_fence_per_frame gf ON gf.frame_start = fl.frame_start
  LEFT JOIN shader_per_frame sp ON sp.frame_start = fl.frame_start
  LEFT JOIN per_frame_cpu_clusters pfcc ON pfcc.frame_start = fl.frame_start
  LEFT JOIN per_frame_freq_changes pffc ON pffc.frame_start = fl.frame_start
  LEFT JOIN per_frame_main_top_slices pfmts ON pfmts.frame_start = fl.frame_start
  LEFT JOIN per_frame_render_top_slices pfrts ON pfrts.frame_start = fl.frame_start
  LEFT JOIN per_frame_binder_detail pfbd ON pfbd.frame_start = fl.frame_start
  LEFT JOIN per_frame_gc_detail pfgd ON pfgd.frame_start = fl.frame_start
  LEFT JOIN per_frame_lock_detail pfld ON pfld.frame_start = fl.frame_start
  LEFT JOIN per_frame_file_io pfio ON pfio.frame_start = fl.frame_start
  LEFT JOIN per_frame_input_events pfie ON pfie.frame_start = fl.frame_start
  LEFT JOIN per_frame_input_slices pfis ON pfis.frame_start = fl.frame_start
  LEFT JOIN per_frame_input_detail pfid ON pfid.frame_start = fl.frame_start
  LEFT JOIN per_frame_input_slice_detail pfisd ON pfisd.frame_start = fl.frame_start
),
-- ========== 11. 根因分类（与 jank_frame_detail 相同优先级 CASE 树） ==========
classified AS (
  SELECT *,
    CASE
      -- P0: Buffer Stuffing 管线背压 — 短路跳过线程分析
      -- App 未错过 deadline，但 BufferQueue 积压导致 dequeueBuffer 背压
      -- 主线程 S 状态来自 syncFrameState 等待，非锁/Binder 问题
      WHEN jank_responsibility = 'BUFFER_STUFFING'
        THEN 'buffer_stuffing'
      -- P0.5: SF 合成超时 — 短路：jank_responsibility 指向 SF，跳过 App 侧分析
      -- Perfetto FrameTimeline 判定 SurfaceFlinger 为掉帧责任方
      WHEN jank_responsibility = 'SF'
        THEN 'sf_composition_slow'
      -- P1: Binder 同步阻塞（top slice 内有大量同步 Binder 重叠）
      WHEN top_slice_ms > slice_critical_ms AND binder_overlap_ms >= binder_overlap_critical_ms
        THEN 'binder_sync_blocking'
      -- P1.5: GC 暂停（帧窗口内 GC 重叠 > 1ms）
      WHEN gc_overlap_ms > 1.0
        THEN 'gc_jank'
      -- P1.6: GC 压力级联 — 帧窗口内多次 GC（>=3 次），内存压力高
      -- 即使单次 GC 重叠 <1ms，密集 GC 累积也会显著影响帧耗时
      WHEN gc_count >= 3 AND gc_overlap_ms > 0.5
        THEN 'gc_pressure_cascade'
      -- P1.7: App input stage 慢。只使用 App 责任/隐形掉帧帧；android.input
      -- handling 或主线程 input slice 都可作为直接证据，同帧事件堆积只是辅助信号。
      WHEN jank_responsibility IN ('APP', 'HIDDEN')
        AND (
          input_handling_ms > frame_budget_ms * ${input_handling_budget_ratio|0.5}
          OR input_slice_ms > frame_budget_ms * ${input_handling_budget_ratio|0.5}
          OR (
            input_event_count >= ${input_event_backlog_threshold|3}
            AND input_handling_ms > frame_budget_ms * 0.25
          )
        )
        THEN 'input_handling_slow'
      -- P2: 小核调度（top slice 多数时间在小核执行）
      WHEN top_slice_ms > slice_critical_ms AND little_run_pct >= 45
        THEN 'small_core_placement'
      -- P3: 关键操作中调度延迟（top slice 中 Runnable 等待占比高）
      WHEN top_slice_ms > slice_critical_ms AND runnable_pct >= 15
        THEN 'sched_delay_in_slice'
      -- P3.5: Shader 编译（RenderThread 有 shader compile 且耗时 > 30% 帧预算）
      WHEN shader_count > 0 AND total_shader_dur_ns > vsync_period_ns * 0.3
        THEN 'shader_compile'
      -- P3.6: GPU fence 等待（RenderThread 长时间等待 GPU fence > 50% 帧预算）
      WHEN max_fence_dur_ns > vsync_period_ns * 0.5
        THEN 'gpu_fence_wait'
      -- P3.7: RenderThread 负载过重 — RT 主动运行占比高（>70%），非 GPU/Shader 等待
      -- 到达此处说明 Shader/GPU fence 已排除；RT 自身计算密集是瓶颈
      WHEN (render_q1_pct + render_q2_pct) > 70 AND render_q4b_pct < 20
        THEN 'render_thread_heavy'
      -- P4: 重度业务负载（>2× 帧预算，即使满频也会超时）
      WHEN top_slice_ms > frame_budget_ms * 2.0
        THEN 'workload_heavy'
      -- P4.5: 温控降频 — 帧内大核最高频率显著低于设备 P95 峰值（<60%）
      -- 放在 workload_heavy 之后：如果帧有明确的 App 侧直接原因（Binder/GC/heavy workload），
      -- 优先归因到直接原因。温控降频是供给侧约束，仅在无更强直接原因时才作为主因
      WHEN device_peak_freq_mhz > 0 AND big_max_freq_mhz > 0
        AND big_max_freq_mhz < device_peak_freq_mhz * 0.60
        AND top_slice_ms > slice_critical_ms
        THEN 'thermal_throttling'
      -- P4.6: CPU 最大频率被限 — 中等程度限频（60%-75%）
      WHEN device_peak_freq_mhz > 0 AND big_max_freq_mhz > 0
        AND big_max_freq_mhz < device_peak_freq_mhz * 0.75
        AND top_slice_ms > slice_critical_ms
        THEN 'cpu_max_limited'
      -- P5: 大核低频（边际情况：slice 在 1x-2x 帧预算区间）
      WHEN top_slice_ms > slice_critical_ms AND big_run_pct >= 40
        AND big_avg_freq_mhz > 0 AND big_max_freq_mhz > 0
        AND big_avg_freq_mhz < big_max_freq_mhz * 0.55
        THEN 'big_core_low_freq'
      -- P6: 频率爬升慢（边际情况：slice 在 1x-2x 帧预算区间）
      WHEN top_slice_ms > slice_critical_ms
        AND ramp_to_high_ms > freq_ramp_critical_ms
        AND top_slice_offset_ms <= ramp_to_high_ms
        THEN 'freq_ramp_slow'
      -- ========== 四象限/IO/Binder 信号（不依赖 top_slice_ms 阈值）==========
      -- P7: CPU 全核饱和 — 双线程同时调度等待高
      WHEN main_q3_pct > 15 AND render_q3_pct > 15
        THEN 'cpu_saturation'
      -- P7.5: 调度延迟（仅主线程 Runnable 高）
      WHEN main_q3_pct > 20
        THEN 'scheduling_delay'
      -- P8: 主线程文件 IO — SharedPreferences/SQLite/fsync 等具体 IO slice
      WHEN file_io_overlap_ms > 1.0
        THEN 'main_thread_file_io'
      -- P8.5: 不可中断等待（D/DK 状态；IO 归因需 io_wait/blocked_function）
      WHEN main_q4a_pct > 20
        THEN 'uninterruptible_wait'
      -- P9: Binder 超时 — 帧窗口内 Binder 累计 >500ms
      WHEN binder_overlap_ms > 500
        THEN 'binder_timeout'
      -- P9.5: 锁/Binder 等待（S/I 状态）
      WHEN main_q4b_pct > 30
        THEN 'lock_binder_wait'
      -- P10: 小核调度（按四象限判断）
      WHEN main_q2_pct > 50
        THEN 'small_core_placement'
      -- ========== 兜底分类 ==========
      -- P11: 工作负载超时兜底（top_slice > critical 但无特定供给侧/四象限因素）
      WHEN top_slice_ms > slice_critical_ms
        THEN 'workload_heavy'
      ELSE 'unknown'
    END as reason_code
  FROM analysis
)
SELECT
  CAST(display_frame_token AS TEXT) as frame_id,
  frame_index,
  printf('%d', frame_start) as start_ts,
  printf('%d', frame_end - frame_start) as dur,
  dur_ms,
  jank_type,
  vsync_missed,
  present_interval_ms,
  jank_responsibility,
  pid,
  process_name,
  reason_code,
  CASE
    WHEN reason_code = 'buffer_stuffing' THEN 'Buffer Stuffing: 管线背压，帧耗时 ' || dur_ms || 'ms，BufferQueue 积压导致跳帧（非 App 问题）'
    WHEN reason_code = 'sf_composition_slow' THEN 'SF合成超时: SurfaceFlinger 侧导致掉帧（非 App 问题），帧耗时 ' || dur_ms || 'ms'
    WHEN reason_code = 'thermal_throttling' THEN '温控降频: 大核最高 ' || big_max_freq_mhz || 'MHz (设备峰值 ' || device_peak_freq_mhz || 'MHz, 仅 ' || ROUND(100.0 * big_max_freq_mhz / NULLIF(device_peak_freq_mhz, 0), 0) || '%)'
    WHEN reason_code = 'binder_sync_blocking' THEN '同步Binder阻塞: "' || top_slice_name || '" 中 Binder 重叠 ' || binder_overlap_ms || 'ms'
    WHEN reason_code = 'gc_jank' THEN 'GC暂停: 帧窗口内 GC 重叠 ' || gc_overlap_ms || 'ms (' || gc_count || ' 次)'
    WHEN reason_code = 'gc_pressure_cascade' THEN 'GC压力级联: 帧窗口内 ' || gc_count || ' 次 GC，总重叠 ' || gc_overlap_ms || 'ms（内存压力高）'
    WHEN reason_code = 'input_handling_slow' THEN '输入处理阻塞: ' || COALESCE(NULLIF(input_stage, ''), 'input') || ' 与帧窗口重叠 ' || input_slice_ms || 'ms，最长相关 slice ' || input_handling_ms || 'ms（预算 ' || frame_budget_ms || 'ms）'
    WHEN reason_code = 'small_core_placement' THEN '小核调度: "' || top_slice_name || '" 小核占比 ' || little_run_pct || '%'
    WHEN reason_code = 'sched_delay_in_slice' THEN '调度延迟: "' || top_slice_name || '" Runnable 占比 ' || runnable_pct || '%'
    WHEN reason_code = 'shader_compile' THEN 'Shader编译: ' || shader_count || ' 次编译，总计 ' || ROUND(total_shader_dur_ns / 1e6, 2) || 'ms'
    WHEN reason_code = 'gpu_fence_wait' THEN 'GPU Fence等待: 最长 ' || ROUND(max_fence_dur_ns / 1e6, 2) || 'ms'
    WHEN reason_code = 'render_thread_heavy' THEN 'RT负载过重: RenderThread 运行占比 ' || (render_q1_pct + render_q2_pct) || '%, 等待仅 ' || render_q4b_pct || '%'
    WHEN reason_code = 'workload_heavy' THEN '负载过重: "' || top_slice_name || '" 耗时 ' || top_slice_ms || 'ms (预算 ' || frame_budget_ms || 'ms)'
    WHEN reason_code = 'cpu_max_limited' THEN 'CPU限频: 大核最高 ' || big_max_freq_mhz || 'MHz (设备峰值 ' || device_peak_freq_mhz || 'MHz, ' || ROUND(100.0 * big_max_freq_mhz / NULLIF(device_peak_freq_mhz, 0), 0) || '%), "' || top_slice_name || '" 耗时 ' || top_slice_ms || 'ms'
    WHEN reason_code = 'big_core_low_freq' THEN '大核低频: 平均 ' || big_avg_freq_mhz || 'MHz (峰值 ' || big_max_freq_mhz || 'MHz)'
    WHEN reason_code = 'freq_ramp_slow' THEN '升频慢: ' || ramp_to_high_ms || 'ms 才达高频'
    WHEN reason_code = 'scheduling_delay' THEN '调度等待: Q3=' || main_q3_pct || '%'
    WHEN reason_code = 'cpu_saturation' THEN 'CPU全核饱和: 主线程 Q3=' || main_q3_pct || '%, RT Q3=' || render_q3_pct || '%（双线程同时调度等待）'
    WHEN reason_code = 'uninterruptible_wait' THEN '不可中断等待: Q4a(D/DK)=' || main_q4a_pct || '%；IO 归因需 io_wait/blocked_function'
    WHEN reason_code = 'main_thread_file_io' THEN '主线程文件IO: 帧内 IO overlap ' || file_io_overlap_ms || 'ms (SharedPreferences/SQLite/fsync)'
    WHEN reason_code = 'lock_binder_wait' THEN '锁/Binder等待: Q4b(S/I)=' || main_q4b_pct || '%'
    WHEN reason_code = 'binder_timeout' THEN 'Binder超时: 帧内 Binder 累计 ' || binder_overlap_ms || 'ms (>500ms)'
    ELSE '未分类 (帧耗时 ' || dur_ms || 'ms)'
  END as primary_cause,
  CASE
    WHEN reason_code = 'buffer_stuffing' THEN '高'
    WHEN reason_code = 'sf_composition_slow' THEN '高'
    WHEN reason_code = 'thermal_throttling' THEN '高'
    WHEN reason_code = 'gc_pressure_cascade' THEN '高'
    WHEN reason_code = 'input_handling_slow' THEN '高'
    WHEN reason_code = 'render_thread_heavy' THEN '中'
    WHEN reason_code = 'cpu_max_limited' THEN '中'
    WHEN reason_code = 'cpu_saturation' THEN '中'
    WHEN reason_code = 'main_thread_file_io' THEN '高'
    WHEN reason_code = 'binder_timeout' THEN '高'
    WHEN top_slice_ms > slice_critical_ms THEN '高'
    WHEN shader_count > 0 THEN '高'
    WHEN max_fence_dur_ns > vsync_period_ns * 0.5 THEN '中'
    WHEN gc_overlap_ms > 1.0 THEN '高'
    WHEN main_q3_pct > 20 OR main_q4a_pct > 20 OR main_q4b_pct > 30 THEN '中'
    ELSE '低'
  END as confidence,
  top_slice_name,
  top_slice_ms,
  -- MainThread 四象限完整输出
  main_q1_pct,
  main_q2_pct,
  main_q3_pct,
  main_q4a_pct,
  main_q4b_pct,
  -- RenderThread 四象限
  COALESCE(render_q1_pct, 0) as render_q1_pct,
  COALESCE(render_q2_pct, 0) as render_q2_pct,
  COALESCE(render_q3_pct, 0) as render_q3_pct,
  COALESCE(render_q4a_pct, 0) as render_q4a_pct,
  COALESCE(render_q4b_pct, 0) as render_q4b_pct,
  -- CPU 频率
  big_avg_freq_mhz,
  big_max_freq_mhz,
  ramp_to_high_ms as ramp_ms,
  -- Top Slice CPU 分布
  little_run_pct as top_slice_little_pct,
  big_run_pct as top_slice_big_pct,
  runnable_pct as top_slice_runnable_pct,
  -- GPU / Shader
  ROUND(max_fence_dur_ns / 1e6, 2) as gpu_fence_ms,
  ROUND(total_fence_dur_ns / 1e6, 2) as gpu_fence_total_ms,
  shader_count,
  ROUND(total_shader_dur_ns / 1e6, 2) as shader_ms,
  -- Binder/GC
  binder_overlap_ms,
  gc_overlap_ms,
  gc_count,
  -- 帧预算参考
  frame_budget_ms,
  -- 设备峰值频率（温控/限频参考）
  device_peak_freq_mhz,
  -- 文件 IO 重叠
  file_io_overlap_ms,
  -- Input pipeline 证据
  input_event_count,
  input_move_count,
  input_handling_ms,
  input_handling_total_ms,
  input_dispatch_ms,
  input_e2e_ms,
  input_slice_ms,
  input_stage,
  input_speculative_events,
  -- 批量详情 JSON 列（供展开行使用）
  cpu_freq_clusters_json,
  freq_timeline_json,
  main_slices_json,
  render_slices_json,
  binder_calls_json,
  gc_events_json,
  lock_contention_json,
  input_events_json,
  input_slices_json
FROM classified
ORDER BY session_id, frame_start
