-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 0403339f9ba204e964aa7ccab7130157ed7149b13da3cfd63bb807484e4bbb96
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

-- 根因分析: 综合四象限、CPU频率、耗时操作等数据，输出明确的根因结论
-- CTEs vsync_ticks, vsync_config, target_threads, thread_states injected via sql_fragments
WITH
-- Fragment: vsync_config
-- Estimates VSync period using median of VSYNC-sf intervals, fallback to 16.67ms (60Hz)
-- Snaps to nearest standard refresh rate (30/60/90/120/144/165 Hz) to avoid
-- half-period toggle contamination and jitter-induced miscalculation.
-- Params: ${start_ts}, ${end_ts}
vsync_ticks AS (
  SELECT c.ts, c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND c.ts >= ${start_ts} - 100000000
    AND c.ts < ${end_ts} + 100000000
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
      (SELECT PERCENTILE(interval_ns, 0.5)
       FROM vsync_ticks
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
-- Fragment: target_threads
-- Resolves MainThread + RenderThread for the target package.
-- Supports standard Android (RenderThread), Flutter (N.raster/N.ui), and Compose.
-- Params: ${package}, ${start_ts}, ${end_ts}
-- Optional: ${main_start_ts}, ${main_end_ts}, ${render_start_ts}, ${render_end_ts}
target_threads AS (
  SELECT t.utid, t.tid, t.name as thread_name, p.pid, p.name as process_name,
    CASE
      WHEN t.tid = p.pid THEN 'MainThread'
      WHEN t.name = 'RenderThread' THEN 'RenderThread'
      WHEN t.name GLOB '[0-9]*.raster' THEN 'RenderThread'
      WHEN t.name GLOB '[0-9]*.ui' THEN 'MainThread'
      ELSE 'Other'
    END as thread_type,
    CASE
      WHEN t.tid = p.pid THEN COALESCE(${main_start_ts}, ${start_ts})
      WHEN t.name = 'RenderThread' THEN COALESCE(${render_start_ts}, ${start_ts})
      WHEN t.name GLOB '[0-9]*.raster' THEN COALESCE(${render_start_ts}, ${start_ts})
      WHEN t.name GLOB '[0-9]*.ui' THEN COALESCE(${main_start_ts}, ${start_ts})
      ELSE ${start_ts}
    END as thread_start_ts,
    CASE
      WHEN t.tid = p.pid THEN COALESCE(${main_end_ts}, ${end_ts})
      WHEN t.name = 'RenderThread' THEN COALESCE(${render_end_ts}, ${end_ts})
      WHEN t.name GLOB '[0-9]*.raster' THEN COALESCE(${render_end_ts}, ${end_ts})
      WHEN t.name GLOB '[0-9]*.ui' THEN COALESCE(${main_end_ts}, ${end_ts})
      ELSE ${end_ts}
    END as thread_end_ts
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND (t.tid = p.pid OR t.name = 'RenderThread'
         OR t.name GLOB '[0-9]*.raster' OR t.name GLOB '[0-9]*.ui')
),
-- Fragment: thread_states_quadrant
-- Depends on: target_threads (CTE), _cpu_topology (VIEW)
-- Maps thread states to Q1-Q4 quadrant classification
-- Q1: Running on big/prime cores (compute-capable)
-- Q2: Running on medium/little cores (power-efficient)
-- Q3: Runnable but not scheduled (scheduling contention)
-- Q4a: Uninterruptible wait (D/DK). Treat as IO only when io_wait=1
--       or blocked_function matches an IO/page-cache family.
-- Q4b: Voluntary sleep (S=interruptible sleep, I=idle) — waiting on lock/futex/binder
thread_states AS (
  SELECT
    tt.thread_type,
    CASE
      WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'little') IN ('prime', 'big') THEN 'Q1'
      WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'little') IN ('medium', 'little') THEN 'Q2'
      WHEN ts.state IN ('R', 'R+') THEN 'Q3'
      WHEN ts.state IN ('D', 'DK') THEN 'Q4a'
      WHEN ts.state IN ('S', 'I') THEN 'Q4b'
      ELSE 'Other'
    END as quadrant,
    SUM(ts.dur) as dur_ns
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts >= tt.thread_start_ts AND ts.ts < tt.thread_end_ts
  GROUP BY tt.thread_type, quadrant
),
-- 3. 计算各线程四象限百分比
quadrant_pct AS (
  SELECT
    thread_type,
    quadrant,
    dur_ns,
    ROUND(100.0 * dur_ns / NULLIF(SUM(dur_ns) OVER (PARTITION BY thread_type), 0), 1) as pct
  FROM thread_states
  WHERE quadrant != 'Other'
),
main_summary AS (
  SELECT
    COALESCE(SUM(CASE WHEN quadrant = 'Q1' THEN pct ELSE 0 END), 0) as q1,
    COALESCE(SUM(CASE WHEN quadrant = 'Q2' THEN pct ELSE 0 END), 0) as q2,
    COALESCE(SUM(CASE WHEN quadrant = 'Q3' THEN pct ELSE 0 END), 0) as q3,
    COALESCE(SUM(CASE WHEN quadrant = 'Q4a' THEN pct ELSE 0 END), 0) as q4a,
    COALESCE(SUM(CASE WHEN quadrant = 'Q4b' THEN pct ELSE 0 END), 0) as q4b
  FROM quadrant_pct WHERE thread_type = 'MainThread'
),
render_summary AS (
  SELECT
    COALESCE(SUM(CASE WHEN quadrant = 'Q1' THEN pct ELSE 0 END), 0) as q1,
    COALESCE(SUM(CASE WHEN quadrant = 'Q2' THEN pct ELSE 0 END), 0) as q2,
    COALESCE(SUM(CASE WHEN quadrant = 'Q3' THEN pct ELSE 0 END), 0) as q3,
    COALESCE(SUM(CASE WHEN quadrant = 'Q4a' THEN pct ELSE 0 END), 0) as q4a,
    COALESCE(SUM(CASE WHEN quadrant = 'Q4b' THEN pct ELSE 0 END), 0) as q4b
  FROM quadrant_pct WHERE thread_type = 'RenderThread'
),
-- 4. 获取最耗时的主线程操作
main_thread_utid AS (
  SELECT t.utid
  FROM thread t JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '') AND (t.tid = p.pid OR t.name GLOB '[0-9]*.ui')
),
main_thread_tid AS (
  SELECT t.tid
  FROM thread t JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '') AND (t.tid = p.pid OR t.name GLOB '[0-9]*.ui')
),
top_slice AS (
  SELECT
    s.name,
    s.ts as slice_ts,
    s.dur as slice_dur_ns,
    ROUND(s.dur / 1e6, 2) as dur_ms
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  WHERE tt.utid IN (SELECT utid FROM main_thread_utid)
    AND s.ts >= COALESCE(${main_start_ts}, ${start_ts})
    AND s.ts < COALESCE(${main_end_ts}, ${end_ts})
    AND s.dur >= 1000000
    AND s.name NOT GLOB '*resynced*'
  ORDER BY s.dur DESC
  LIMIT 1
),
top_slice_bounds AS (
  SELECT
    slice_ts as slice_start_ns,
    slice_ts + slice_dur_ns as slice_end_ns,
    slice_dur_ns
  FROM top_slice
),
top_slice_state_overlap AS (
  SELECT
    ts.state,
    ts.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type,
    (
      CASE
        WHEN ts.ts + ts.dur < b.slice_end_ns THEN ts.ts + ts.dur
        ELSE b.slice_end_ns
      END
      -
      CASE
        WHEN ts.ts > b.slice_start_ns THEN ts.ts
        ELSE b.slice_start_ns
      END
    ) as overlap_ns
  FROM thread_state ts
  JOIN main_thread_utid mtu ON ts.utid = mtu.utid
  JOIN top_slice_bounds b
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts < b.slice_end_ns
    AND ts.ts + ts.dur > b.slice_start_ns
),
top_slice_cpu_mix AS (
  SELECT
    ROUND(
      100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('medium', 'little') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF((SELECT slice_dur_ns FROM top_slice_bounds), 0),
      1
    ) as little_run_pct,
    ROUND(
      100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF((SELECT slice_dur_ns FROM top_slice_bounds), 0),
      1
    ) as big_run_pct,
    ROUND(
      100.0 * SUM(CASE WHEN state = 'R' AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF((SELECT slice_dur_ns FROM top_slice_bounds), 0),
      1
    ) as runnable_pct,
    ROUND(
      100.0 * SUM(CASE WHEN state IN ('S', 'D', 'I', 'DK') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF((SELECT slice_dur_ns FROM top_slice_bounds), 0),
      1
    ) as blocked_pct
  FROM top_slice_state_overlap
),
-- 5. 获取 CPU 频率
freq_info AS (
  SELECT
    ROUND(AVG(CASE WHEN ct.core_type IN ('prime', 'big') THEN c.value END) / 1000, 0) as big_avg_freq,
    ROUND(MAX(CASE WHEN ct.core_type IN ('prime', 'big') THEN c.value END) / 1000, 0) as big_max_freq,
    ROUND(MIN(CASE WHEN ct.core_type IN ('prime', 'big') THEN c.value END) / 1000, 0) as big_min_freq,
    ROUND(AVG(CASE WHEN ct.core_type IN ('medium', 'little') THEN c.value END) / 1000, 0) as little_avg_freq,
    ROUND(MAX(CASE WHEN ct.core_type IN ('medium', 'little') THEN c.value END) / 1000, 0) as little_max_freq,
    ROUND(MIN(CASE WHEN ct.core_type IN ('medium', 'little') THEN c.value END) / 1000, 0) as little_min_freq
  FROM counter c
  JOIN cpu_counter_track t ON c.track_id = t.id
  LEFT JOIN _cpu_topology ct ON t.cpu = ct.cpu_id
  WHERE t.name = 'cpufreq'
    AND c.ts >= ${start_ts} AND c.ts < ${end_ts}
),
top_slice_freq AS (
  SELECT
    ROUND(AVG(CASE WHEN ct.core_type IN ('prime', 'big') THEN c.value END) / 1000, 0) as top_big_avg_freq_mhz,
    ROUND(MAX(CASE WHEN ct.core_type IN ('prime', 'big') THEN c.value END) / 1000, 0) as top_big_max_freq_mhz,
    ROUND(MIN(CASE WHEN ct.core_type IN ('prime', 'big') THEN c.value END) / 1000, 0) as top_big_min_freq_mhz,
    ROUND(AVG(CASE WHEN ct.core_type IN ('medium', 'little') THEN c.value END) / 1000, 0) as top_little_avg_freq_mhz
  FROM counter c
  JOIN cpu_counter_track t ON c.track_id = t.id
  LEFT JOIN _cpu_topology ct ON t.cpu = ct.cpu_id
  WHERE t.name = 'cpufreq'
    AND EXISTS (SELECT 1 FROM top_slice_bounds)
    AND c.ts >= (SELECT slice_start_ns FROM top_slice_bounds)
    AND c.ts < (SELECT slice_end_ns FROM top_slice_bounds)
),
big_freq_window AS (
  SELECT c.ts, c.value as freq_khz
  FROM counter c
  JOIN cpu_counter_track t ON c.track_id = t.id
  WHERE t.name = 'cpufreq'
    AND t.cpu IN (SELECT cpu_id FROM _cpu_topology WHERE core_type IN ('prime', 'big'))
    AND c.ts >= ${start_ts}
    AND c.ts < ${end_ts}
),
big_freq_stats AS (
  SELECT
    MAX(freq_khz) as peak_khz,
    MIN(freq_khz) as min_khz,
    AVG(freq_khz) as avg_khz
  FROM big_freq_window
),
big_freq_ramp AS (
  SELECT
    ROUND(
      (
        COALESCE(
          MIN(
            CASE
              WHEN b.freq_khz >=
                CASE
                  WHEN s.peak_khz IS NULL THEN NULL
                  WHEN s.peak_khz * 0.70 > 1800000 THEN s.peak_khz * 0.70
                  ELSE 1800000
                END
              THEN b.ts
            END
          ),
          ${end_ts}
        ) - ${start_ts}
      ) / 1e6,
      2
    ) as ramp_to_high_ms,
    ROUND(
      (COALESCE(MIN(CASE WHEN b.freq_khz >= 2000000 THEN b.ts END), ${end_ts}) - ${start_ts}) / 1e6,
      2
    ) as ramp_to_2g_ms
  FROM big_freq_window b
  CROSS JOIN big_freq_stats s
),
-- 6. IO/page-cache 候选检测（主线程 D/DK + io_wait/blocked_function）
io_block AS (
  SELECT COALESCE(ROUND(SUM(ts2.dur) / 1e6, 2), 0) as io_block_ms
  FROM thread_state ts2
  JOIN target_threads tt2 ON ts2.utid = tt2.utid
  WHERE tt2.thread_type = 'MainThread'
    AND ts2.ts >= ${start_ts} AND ts2.ts < ${end_ts}
    AND ts2.state IN ('D', 'DK')
    AND (
      COALESCE(ts2.io_wait, 0) = 1
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%filemap%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%page_fault%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%wait_on_page%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%folio_wait%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%io_schedule%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%submit_bio%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%sync%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%blk_%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%ext4%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%f2fs%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%erofs%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%ufshcd%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%mmc_%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%dm_%'
    )
),
-- 7. 调度延迟检测（Runnable 等待）
sched_latency AS (
  SELECT
    COALESCE(ROUND(MAX(ts3.dur) / 1e6, 2), 0) as max_sched_ms,
    COALESCE(ROUND(SUM(ts3.dur) / 1e6, 2), 0) as total_sched_ms
  FROM thread_state ts3
  JOIN target_threads tt3 ON ts3.utid = tt3.utid
  WHERE tt3.thread_type = 'MainThread'
    AND ts3.ts >= ${start_ts} AND ts3.ts < ${end_ts}
    AND ts3.state = 'R'
),
-- 8. GPU Fence / GPU 同步检测
-- 包含 GPU fence 等待、eglSwapBuffers（GPU backpressure）、dequeueBuffer（BufferQueue 阻塞）
gpu_fence AS (
  SELECT COALESCE(ROUND(SUM(s.dur) / 1e6, 2), 0) as fence_ms
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND (t.name = 'RenderThread' OR t.name GLOB '[0-9]*.raster')
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
    AND (s.name GLOB '*Fence*' OR s.name GLOB '*fence*'
         OR s.name GLOB '*eglSwapBuffers*'
         OR s.name GLOB '*dequeueBuffer*')
),
-- 8b. Shader 编译检测（RenderThread 上的着色器编译/管线创建 slice）
shader_compile AS (
  SELECT
    COALESCE(ROUND(SUM(s.dur) / 1e6, 2), 0) as shader_ms,
    COUNT(*) as shader_count
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND (t.name = 'RenderThread' OR t.name GLOB '[0-9]*.raster')
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
    AND (s.name GLOB '*shader*' OR s.name GLOB '*Shader*'
         OR s.name GLOB '*Compile*' OR s.name GLOB '*compile*'
         OR s.name GLOB 'GrGLGpu*'
         OR s.name GLOB '*Pipeline*Create*'
         OR s.name GLOB '*programCache*')
),
-- 9. CPU 簇负载检测（动态核心计数，适配所有 SoC 拓扑）
cluster_core_counts AS (
  SELECT
    COUNT(DISTINCT CASE WHEN COALESCE(ct.core_type, 'unknown') IN ('prime', 'big') THEN ts.cpu END) as big_cores,
    COUNT(DISTINCT CASE WHEN COALESCE(ct.core_type, 'unknown') IN ('medium', 'little') THEN ts.cpu END) as little_cores
  FROM thread_state ts
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts < ${end_ts}
    AND ts.ts + ts.dur > ${start_ts}
    AND ts.state = 'Running'
    AND ts.cpu IS NOT NULL
),
cluster_load AS (
  SELECT
    ROUND(100.0 * SUM(CASE WHEN COALESCE(ct.core_type, 'unknown') IN ('prime', 'big') THEN
      MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts})
    ELSE 0 END) / NULLIF((${end_ts} - ${start_ts}) * MAX((SELECT big_cores FROM cluster_core_counts), 1), 0), 1) as big_load_pct,
    ROUND(100.0 * SUM(CASE WHEN COALESCE(ct.core_type, 'unknown') IN ('medium', 'little') THEN
      MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts})
    ELSE 0 END) / NULLIF((${end_ts} - ${start_ts}) * MAX((SELECT little_cores FROM cluster_core_counts), 1), 0), 1) as little_load_pct
  FROM thread_state ts
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts < ${end_ts}
    AND ts.ts + ts.dur > ${start_ts}
    AND ts.state = 'Running'
    AND ts.cpu IS NOT NULL
),
-- 10. GC 事件与帧窗口重叠检测
-- android_garbage_collection_events view 由 prerequisites 中的
-- INCLUDE PERFETTO MODULE android.garbage_collection 保证存在（可能为空）
gc_frame_overlap AS (
  SELECT
    COALESCE(ROUND(SUM(
      CASE WHEN MIN(gc.gc_ts + gc.gc_dur, ${end_ts}) > MAX(gc.gc_ts, ${start_ts})
        THEN MIN(gc.gc_ts + gc.gc_dur, ${end_ts}) - MAX(gc.gc_ts, ${start_ts})
        ELSE 0 END
    ) / 1e6, 2), 0) as gc_overlap_ms,
    COUNT(*) as gc_count
  FROM android_garbage_collection_events gc
  JOIN thread t ON gc.tid = t.tid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND gc.gc_ts < ${end_ts}
    AND gc.gc_ts + gc.gc_dur > ${start_ts}
),
-- 11. 主线程同步 Binder 与关键 slice 重叠分析
binder_sync_main AS (
  SELECT
    bt.client_ts,
    bt.client_dur,
    bt.server_process
  FROM android_binder_txns bt
  WHERE bt.client_tid IN (SELECT tid FROM main_thread_tid)
    AND bt.is_sync = 1
    AND bt.client_ts < ${end_ts}
    AND bt.client_ts + bt.client_dur > ${start_ts}
),
binder_frame AS (
  SELECT
    ROUND(COALESCE(SUM(client_dur), 0) / 1e6, 2) as sync_total_ms,
    ROUND(COALESCE(MAX(client_dur), 0) / 1e6, 2) as sync_max_ms,
    COUNT(*) as sync_count
  FROM binder_sync_main
),
binder_overlap AS (
  SELECT
    ROUND(
      COALESCE(
        SUM(
          CASE
            WHEN b.client_ts < tsb.slice_end_ns
              AND b.client_ts + b.client_dur > tsb.slice_start_ns
            THEN
              (
                CASE
                  WHEN b.client_ts + b.client_dur < tsb.slice_end_ns THEN b.client_ts + b.client_dur
                  ELSE tsb.slice_end_ns
                END
                -
                CASE
                  WHEN b.client_ts > tsb.slice_start_ns THEN b.client_ts
                  ELSE tsb.slice_start_ns
                END
              )
            ELSE 0
          END
        ),
        0
      ) / 1e6,
      2
    ) as overlap_ms,
    ROUND(
      COALESCE(
        MAX(
          CASE
            WHEN b.client_ts < tsb.slice_end_ns
              AND b.client_ts + b.client_dur > tsb.slice_start_ns
            THEN
              (
                CASE
                  WHEN b.client_ts + b.client_dur < tsb.slice_end_ns THEN b.client_ts + b.client_dur
                  ELSE tsb.slice_end_ns
                END
                -
                CASE
                  WHEN b.client_ts > tsb.slice_start_ns THEN b.client_ts
                  ELSE tsb.slice_start_ns
                END
              )
            ELSE 0
          END
        ),
        0
      ) / 1e6,
      2
    ) as max_overlap_ms,
    COALESCE(
      MAX(
        CASE
          WHEN b.client_ts < tsb.slice_end_ns
            AND b.client_ts + b.client_dur > tsb.slice_start_ns
          THEN b.server_process
          ELSE NULL
        END
      ),
      ''
    ) as overlap_server
  FROM binder_sync_main b
  JOIN top_slice_bounds tsb
),
-- 12. 综合根因判断
analysis AS (
  SELECT
    (SELECT dur_ms FROM top_slice) as slice_dur,
    (SELECT name FROM top_slice) as slice_name,
    ROUND(((SELECT slice_ts FROM top_slice) - ${start_ts}) / 1e6, 2) as top_slice_offset_ms,
    (SELECT q1 FROM main_summary) as main_q1,
    (SELECT q2 FROM main_summary) as main_q2,
    (SELECT q3 FROM main_summary) as main_q3,
    (SELECT q4a FROM main_summary) as main_q4a,
    (SELECT q4b FROM main_summary) as main_q4b,
    (SELECT q1 FROM render_summary) as render_q1,
    (SELECT q2 FROM render_summary) as render_q2,
    (SELECT q3 FROM render_summary) as render_q3,
    (SELECT q4a FROM render_summary) as render_q4a,
    (SELECT q4b FROM render_summary) as render_q4b,
    (SELECT big_avg_freq FROM freq_info) as big_freq,
    (SELECT big_max_freq FROM freq_info) as big_freq_peak,
    (SELECT big_min_freq FROM freq_info) as big_freq_min,
    (SELECT little_avg_freq FROM freq_info) as little_freq,
    (SELECT little_max_freq FROM freq_info) as little_freq_peak,
    (SELECT little_min_freq FROM freq_info) as little_freq_min,
    (SELECT little_run_pct FROM top_slice_cpu_mix) as top_slice_little_pct,
    (SELECT big_run_pct FROM top_slice_cpu_mix) as top_slice_big_pct,
    (SELECT runnable_pct FROM top_slice_cpu_mix) as top_slice_runnable_pct,
    (SELECT blocked_pct FROM top_slice_cpu_mix) as top_slice_blocked_pct,
    (SELECT top_big_avg_freq_mhz FROM top_slice_freq) as top_big_avg_freq_mhz,
    (SELECT top_big_max_freq_mhz FROM top_slice_freq) as top_big_max_freq_mhz,
    (SELECT top_big_min_freq_mhz FROM top_slice_freq) as top_big_min_freq_mhz,
    (SELECT top_little_avg_freq_mhz FROM top_slice_freq) as top_little_avg_freq_mhz,
    (SELECT ramp_to_high_ms FROM big_freq_ramp) as ramp_to_high_ms,
    (SELECT ramp_to_2g_ms FROM big_freq_ramp) as ramp_to_2g_ms,
    (SELECT overlap_ms FROM binder_overlap) as binder_overlap_ms,
    (SELECT max_overlap_ms FROM binder_overlap) as binder_max_overlap_ms,
    (SELECT overlap_server FROM binder_overlap) as binder_overlap_server,
    (SELECT sync_total_ms FROM binder_frame) as binder_sync_total_ms,
    (SELECT sync_max_ms FROM binder_frame) as binder_sync_max_ms,
    (SELECT sync_count FROM binder_frame) as binder_sync_count,
    (SELECT io_block_ms FROM io_block) as io_block_ms,
    (SELECT max_sched_ms FROM sched_latency) as max_sched_ms,
    (SELECT total_sched_ms FROM sched_latency) as total_sched_ms,
    (SELECT fence_ms FROM gpu_fence) as fence_ms,
    (SELECT shader_ms FROM shader_compile) as shader_ms,
    (SELECT shader_count FROM shader_compile) as shader_count,
    (SELECT gc_overlap_ms FROM gc_frame_overlap) as gc_overlap_ms,
    (SELECT gc_count FROM gc_frame_overlap) as gc_count,
    (SELECT big_load_pct FROM cluster_load) as big_load_pct,
    (SELECT little_load_pct FROM cluster_load) as little_load_pct,
    ROUND((SELECT vsync_period_ns FROM vsync_config) / 1e6, 2) as frame_budget_ms,
    ROUND(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.50, 2) as slice_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.20, 2.0), 2) as slice_warning_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.18, 1.5), 2) as gpu_fence_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.06, 0.8), 2) as gpu_fence_warning_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.30, 3.5), 2) as sched_max_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.18, 2.0), 2) as total_sched_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.12, 1.5), 2) as io_block_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.18, 1.5), 2) as binder_overlap_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.35, 2.0), 2) as freq_ramp_critical_ms
)
, classified AS (
  SELECT
    *,
    CASE
      -- P0: Buffer Stuffing 管线背压 — 短路跳过线程分析
      WHEN '${jank_responsibility}' = 'BUFFER_STUFFING'
        THEN 'buffer_stuffing'
      -- P1: Binder 同步阻塞（特定可操作，阻塞可能占据 slice 大部分时间）
      WHEN slice_dur > slice_critical_ms
        AND binder_overlap_ms >= binder_overlap_critical_ms
        THEN 'binder_sync_blocking'
      -- P2: 小核调度（可能导致 3-4x 性能损失，可操作）
      WHEN slice_dur > slice_critical_ms
        AND COALESCE(top_slice_little_pct, 0) >= 45
        THEN 'small_core_placement'
      -- P3: 关键操作中的调度延迟
      WHEN slice_dur > slice_critical_ms
        AND COALESCE(top_slice_runnable_pct, 0) >= 15
        THEN 'sched_delay_in_slice'
      -- P4: 重度业务负载（>2x 帧预算）— 即使在满频下也会超时
      -- 频率/调度等供给侧因素只是放大因素，不是根因
      WHEN slice_dur > frame_budget_ms * 2.0
        THEN 'workload_heavy'
      -- P5: 大核低频（仅适用于边际情况：slice 在 1x-2x 帧预算区间）
      WHEN slice_dur > slice_critical_ms
        AND COALESCE(top_slice_big_pct, 0) >= 40
        AND COALESCE(top_big_avg_freq_mhz, 0) > 0
        AND COALESCE(top_big_max_freq_mhz, 0) > 0
        AND top_big_avg_freq_mhz < top_big_max_freq_mhz * 0.55
        THEN 'big_core_low_freq'
      -- P6: 频率爬升慢（仅适用于边际情况：slice 在 1x-2x 帧预算区间）
      WHEN slice_dur > slice_critical_ms
        AND COALESCE(ramp_to_high_ms, 0) > freq_ramp_critical_ms
        AND COALESCE(top_slice_offset_ms, 0) <= ramp_to_high_ms
        THEN 'freq_ramp_slow'
      -- P7: 工作负载超时兜底（1x-2x 帧预算，无特定供给侧因素）
      WHEN slice_dur > slice_critical_ms
        THEN 'workload_heavy'
      -- P8: GC 导致帧卡顿（GC pause 与帧窗口重叠 > 1ms）
      WHEN gc_overlap_ms > 1.0
        THEN 'gc_jank'
      WHEN max_sched_ms > sched_max_critical_ms
        OR total_sched_ms > total_sched_critical_ms
        OR main_q3 > 20
        THEN 'scheduling_delay'
      WHEN main_q2 > 50
        THEN 'small_core_placement'
      -- Shader 编译（首次渲染特定图形效果时的编译开销）
      WHEN COALESCE(shader_ms, 0) > gpu_fence_warning_ms
        THEN 'shader_compile'
      -- GPU Fence 等待（渲染管线瓶颈，比 CPU 负载更具可操作性）
      WHEN fence_ms > gpu_fence_warning_ms
        THEN 'gpu_wait'
      WHEN big_freq > 0 AND big_freq_peak > 0 AND big_freq < big_freq_peak * 0.45
        THEN 'big_core_low_freq'
      WHEN big_load_pct > 90 OR (big_load_pct > 70 AND little_load_pct > 70)
        THEN 'cpu_load_high'
      WHEN io_block_ms > io_block_critical_ms
        THEN 'io_page_cache_wait'
      WHEN main_q4a > 20
        THEN 'uninterruptible_wait'
      WHEN main_q4b > 30
        THEN 'lock_binder_wait'
      ELSE 'unknown'
    END as reason_code
  FROM analysis
)
, base_result AS (
  SELECT
    CASE
      -- 优先级1: 主线程有明确耗时操作（相对帧预算）
      WHEN slice_dur > slice_critical_ms THEN
        '主线程耗时操作 "' || slice_name || '" 占用 ' || slice_dur || 'ms (帧预算 ' || frame_budget_ms || 'ms)'
      -- 优先级2: GPU Fence 等待（相对帧预算）
      WHEN fence_ms > gpu_fence_critical_ms THEN
        'GPU Fence 等待 ' || ROUND(fence_ms, 1) || 'ms，GPU 繁忙无法及时完成渲染'
      -- 优先级3: 严重调度延迟（相对帧预算）
      WHEN max_sched_ms > sched_max_critical_ms THEN
        '主线程调度延迟严重: 最大等待 ' || ROUND(max_sched_ms, 1) || 'ms'
      -- 优先级4: 主线程大量等待调度 (Q3 > 20%)
      WHEN main_q3 > 20 THEN
        '主线程 CPU 争抢严重 (' || main_q3 || '% 时间在等待调度)'
      -- 优先级5: 主线程 IO/page-cache 等待候选（相对帧预算）
      WHEN io_block_ms > io_block_critical_ms THEN
        '主线程 IO/page-cache 等待候选 ' || ROUND(io_block_ms, 1) || 'ms (D/DK + io_wait/blocked_function)'
      -- 优先级6: 总调度延迟（相对帧预算）
      WHEN total_sched_ms > total_sched_critical_ms THEN
        '主线程 Runnable 累计等待 ' || ROUND(total_sched_ms, 1) || 'ms'
      -- 优先级7a: 主线程不可中断等待 (Q4a > 20%)
      WHEN main_q4a > 20 THEN
        '主线程不可中断等待 (D/DK 状态)，占比 ' || main_q4a || '%；IO 归因需 io_wait/blocked_function'
      -- 优先级7b: 主线程锁/Binder等待 (Q4b > 30%)
      WHEN main_q4b > 30 THEN
        '主线程锁/Binder 等待 (S/I 状态)，占比 ' || main_q4b || '%'
      -- 优先级8: RenderThread 休眠 (Q4 > 50%)
      WHEN (render_q4a + render_q4b) > 50 THEN
        'RenderThread 长时间休眠 (' || (render_q4a + render_q4b) || '%)，等待主线程或 GPU'
      -- 优先级9: 主线程在小核运行 (Q2 > 50%)
      WHEN main_q2 > 50 THEN
        '主线程被调度到小核 (' || main_q2 || '%)，CPU 能力不足'
      -- 优先级10: CPU 频率问题
      WHEN big_freq < 1200 AND big_freq > 0 THEN
        '大核频率过低 (' || big_freq || 'MHz)，可能触发温控限频'
      -- 优先级11: 大核簇负载过高 (>90%)
      WHEN big_load_pct > 90 THEN
        '大核簇负载 ' || ROUND(big_load_pct, 0) || '%，CPU 资源严重不足'
      -- 优先级12: GPU Fence 中等延迟（相对帧预算）
      WHEN fence_ms > gpu_fence_warning_ms THEN
        'GPU Fence 等待 ' || ROUND(fence_ms, 1) || 'ms'
      -- 优先级13: CPU 整体负载高
      WHEN big_load_pct > 70 AND little_load_pct > 70 THEN
        'CPU 整体负载高 (大核 ' || ROUND(big_load_pct, 0) || '%, 小核 ' || ROUND(little_load_pct, 0) || '%)'
      -- 优先级14: 有中等耗时操作（相对帧预算）
      WHEN slice_dur > slice_warning_ms THEN
        '主线程操作 "' || slice_name || '" 耗时 ' || slice_dur || 'ms'
      -- 默认
      ELSE '帧耗时 ${dur_ms}ms 超过 VSync 周期(' || frame_budget_ms || 'ms)'
    END as primary_cause,
    CASE
      WHEN reason_code = 'buffer_stuffing' THEN
        'Buffer Stuffing: 管线背压，帧耗时 ' || ${dur_ms} || 'ms，BufferQueue 积压导致跳帧（非 App 问题）'
      WHEN reason_code = 'binder_sync_blocking' THEN
        'Binder 同步阻塞：关键操作与同步Binder重叠 ' || binder_overlap_ms || 'ms（累计 ' ||
        binder_sync_total_ms || 'ms' ||
        CASE
          WHEN COALESCE(binder_overlap_server, '') != '' THEN '，对端 ' || binder_overlap_server || ''
          ELSE ''
        END || '）'
      WHEN reason_code = 'small_core_placement' THEN
        '线程更多跑在小核：关键操作小核运行占比 ' || COALESCE(top_slice_little_pct, 0) ||
        '%（大核占比 ' || COALESCE(top_slice_big_pct, 0) || '%）'
      WHEN reason_code = 'sched_delay_in_slice' THEN
        '调度延迟：关键操作中 Runnable 等待占比 ' || COALESCE(top_slice_runnable_pct, 0) ||
        '%，主线程最大调度等待 ' || COALESCE(max_sched_ms, 0) || 'ms'
      WHEN reason_code = 'big_core_low_freq' THEN
        '大核低频：关键操作大核运行占比 ' || COALESCE(top_slice_big_pct, 0) ||
        '%，但平均频率仅 ' || COALESCE(top_big_avg_freq_mhz, big_freq) || 'MHz（片内峰值 ' ||
        COALESCE(top_big_max_freq_mhz, big_freq_peak) || 'MHz）'
      WHEN reason_code = 'freq_ramp_slow' THEN
        '频率爬升慢：帧开始后 ' || COALESCE(ramp_to_high_ms, 0) ||
        'ms 才升到高频，关键操作起点 +' || COALESCE(top_slice_offset_ms, 0) || 'ms'
      WHEN reason_code = 'workload_heavy' THEN
        CASE
          WHEN slice_name GLOB '*RV*Prefetch*' OR slice_name GLOB '*OnBind*' OR slice_name GLOB '*Adapter*bind*' OR slice_name GLOB '*bind*'
            THEN '业务负载重：列表预取/绑定逻辑在主线程串行执行 ' || slice_dur || 'ms（超帧预算 ' || ROUND(slice_dur / NULLIF(frame_budget_ms, 0), 1) || '倍）'
          WHEN COALESCE(ramp_to_high_ms, 0) > freq_ramp_critical_ms
            THEN '业务负载重：操作耗时 ' || slice_dur || 'ms（超帧预算 ' || ROUND(slice_dur / NULLIF(frame_budget_ms, 0), 1) || '倍），频率爬升 ' || ramp_to_high_ms || 'ms 为次要加剧因素'
          ELSE '业务负载重：主线程操作耗时 ' || slice_dur || 'ms（超帧预算 ' || ROUND(slice_dur / NULLIF(frame_budget_ms, 0), 1) || '倍）'
        END
      WHEN reason_code = 'scheduling_delay' THEN
        '调度延迟：主线程 Runnable 累计 ' || COALESCE(total_sched_ms, 0) ||
        'ms（最大 ' || COALESCE(max_sched_ms, 0) || 'ms）'
      WHEN reason_code = 'cpu_load_high' THEN
        'CPU 负载高：大核负载 ' || COALESCE(big_load_pct, 0) ||
        '%，小核负载 ' || COALESCE(little_load_pct, 0) || '%'
      WHEN reason_code = 'io_page_cache_wait' THEN
        'IO/page-cache 等待候选：主线程 D/DK 且有 io_wait/blocked_function ' || COALESCE(io_block_ms, 0) || 'ms，Q4a 占比 ' || COALESCE(main_q4a, 0) || '%'
      WHEN reason_code = 'uninterruptible_wait' THEN
        '不可中断等待：主线程 Q4a(D/DK) 占比 ' || COALESCE(main_q4a, 0) || '%；IO 归因需 io_wait/blocked_function'
      WHEN reason_code = 'lock_binder_wait' THEN
        '锁/Binder 等待：主线程可中断睡眠(S/I)，Q4b 占比 ' || COALESCE(main_q4b, 0) || '%'
      WHEN reason_code = 'shader_compile' THEN
        'Shader 编译：RenderThread 上着色器编译耗时 ' || COALESCE(shader_ms, 0) || 'ms（' || COALESCE(shader_count, 0) || ' 次），首次渲染或新视觉效果触发'
      WHEN reason_code = 'gpu_wait' THEN
        'GPU 等待：RenderThread/GPU Fence 累计等待 ' || COALESCE(fence_ms, 0) || 'ms'
      WHEN reason_code = 'gc_jank' THEN
        'GC 暂停：帧窗口内 GC 重叠 ' || COALESCE(gc_overlap_ms, 0) || 'ms（' || COALESCE(gc_count, 0) || ' 次 GC）'
      ELSE NULL
    END as deep_reason,
    CASE
      WHEN reason_code = 'buffer_stuffing' THEN '非 App 问题：BufferQueue 管线背压导致跳帧。检查帧率设置是否匹配显示刷新率，或优化渲染管线吞吐'
      WHEN reason_code = 'binder_sync_blocking' THEN '优化方向：减少主线程同步 Binder（异步化/批量化/结果缓存）并压缩关键路径 IPC'
      WHEN reason_code = 'small_core_placement' THEN '优化方向：保证关键滚动路径优先使用大核，减少后台线程对主线程的抢占'
      WHEN reason_code = 'sched_delay_in_slice' OR reason_code = 'scheduling_delay' THEN '优化方向：降低同窗并发与高优线程竞争，缩短主线程 Runnable 等待'
      WHEN reason_code = 'big_core_low_freq' THEN '优化方向：在输入/滚动前预拉频，避免大核低频执行关键 UI 热路径'
      WHEN reason_code = 'freq_ramp_slow' THEN '优化方向：使用 touch/scroll boost 提前拉频，减少频率爬升滞后'
      WHEN reason_code = 'workload_heavy' THEN
        CASE
          WHEN slice_name GLOB '*RV*Prefetch*' OR slice_name GLOB '*OnBind*' OR slice_name GLOB '*Adapter*bind*' OR slice_name GLOB '*bind*'
            THEN '优化方向：拆分 RV Prefetch/OnBind 重逻辑，预计算和缓存绑定数据，避免主线程串行重活'
          ELSE '优化方向：把关键帧内重逻辑拆分到后台并做结果复用，缩短主线程单次执行时长'
        END
      WHEN reason_code = 'cpu_load_high' THEN '优化方向：降低 CPU 总负载并限制后台并发，优先保障 UI 与 RenderThread 预算'
      WHEN reason_code = 'io_page_cache_wait' THEN '优化方向：补齐文件/数据库/Provider 证据；确认后将同步 IO 移至后台线程或使用异步 IO'
      WHEN reason_code = 'uninterruptible_wait' THEN '优化方向：先查 io_wait、blocked_function、page fault 和文件/数据库 slice，确认是否为 IO 后再定向优化'
      WHEN reason_code = 'lock_binder_wait' THEN '优化方向：减少主线程同步等待（Binder/锁/futex），缩短临界区和同步链路'
      WHEN reason_code = 'shader_compile' THEN '优化方向：使用 PrecompiledShaders / Shader Warm-up 在启动时预编译着色器，避免滑动时动态编译'
      WHEN reason_code = 'gpu_wait' THEN '优化方向：降低 draw 复杂度/overdraw，减少 GPU Fence 等待'
      WHEN reason_code = 'gc_jank' THEN '优化方向：减少帧渲染路径上的对象分配，使用对象池化/预分配，避免 GC 暂停重叠关键帧'
      ELSE '优化方向：扩大同窗样本做聚类，确认该慢原因是否稳定复现'
    END as optimization_hint,
    reason_code,
    CASE
      WHEN reason_code = 'buffer_stuffing' THEN 'Buffer Stuffing 管线背压（jank_type=${jank_type}）'
      WHEN reason_code = 'binder_sync_blocking' THEN '同步 Binder 重叠 ' || COALESCE(binder_overlap_ms, 0) || 'ms'
      WHEN reason_code = 'small_core_placement' THEN '关键操作小核占比 ' || COALESCE(top_slice_little_pct, 0) || '%'
      WHEN reason_code = 'sched_delay_in_slice' THEN '关键操作 Runnable 占比 ' || COALESCE(top_slice_runnable_pct, 0) || '%'
      WHEN reason_code = 'big_core_low_freq' THEN '关键操作大核频率 ' || COALESCE(top_big_avg_freq_mhz, big_freq) || 'MHz'
      WHEN reason_code = 'freq_ramp_slow' THEN '高频拉升耗时 ' || COALESCE(ramp_to_high_ms, 0) || 'ms'
      WHEN reason_code = 'workload_heavy' THEN '操作 "' || COALESCE(slice_name, 'unknown') || '" 耗时 ' || COALESCE(slice_dur, 0) || 'ms（超帧预算 ' || ROUND(COALESCE(slice_dur, 0) / NULLIF(frame_budget_ms, 0), 1) || 'x）' ||
        CASE WHEN COALESCE(ramp_to_high_ms, 0) > freq_ramp_critical_ms THEN '，频率爬升 ' || ramp_to_high_ms || 'ms 加剧' ELSE '' END
      WHEN reason_code = 'gc_jank' THEN 'GC 重叠 ' || COALESCE(gc_overlap_ms, 0) || 'ms（' || COALESCE(gc_count, 0) || ' 次）'
      WHEN reason_code = 'shader_compile' THEN 'Shader 编译 ' || COALESCE(shader_ms, 0) || 'ms（' || COALESCE(shader_count, 0) || ' 次）'
      WHEN fence_ms > gpu_fence_warning_ms THEN 'GPU Fence 等待 ' || ROUND(fence_ms, 1) || 'ms'
      WHEN total_sched_ms > (total_sched_critical_ms * 0.5) THEN '调度等待累计 ' || ROUND(total_sched_ms, 1) || 'ms'
      WHEN big_load_pct > 70 THEN '大核负载 ' || ROUND(big_load_pct, 0) || '%'
      WHEN big_freq > 0 AND big_freq < 1500 THEN '大核平均频率 ' || big_freq || 'MHz'
      WHEN main_q2 > 30 THEN '小核运行占比 ' || main_q2 || '%'
      ELSE NULL
    END as secondary_info,
    CASE
      WHEN slice_dur > slice_critical_ms THEN '高'
      WHEN gc_overlap_ms > 1.0 THEN '高'
      WHEN fence_ms > gpu_fence_critical_ms THEN '高'
      WHEN max_sched_ms > sched_max_critical_ms THEN '高'
      WHEN main_q3 > 20 THEN '高'
      WHEN io_block_ms > io_block_critical_ms THEN '高'
      WHEN total_sched_ms > total_sched_critical_ms THEN '高'
      WHEN big_load_pct > 90 THEN '高'
      WHEN COALESCE(shader_ms, 0) > gpu_fence_warning_ms THEN '高'
      WHEN main_q4a > 20 OR main_q4b > 30 THEN '中'
      WHEN fence_ms > gpu_fence_warning_ms THEN '中'
      WHEN big_load_pct > 70 AND little_load_pct > 70 THEN '中'
      WHEN slice_dur > slice_warning_ms THEN '中'
      ELSE '低'
    END as confidence,
    CASE
      -- SF 合成超时短路：jank_responsibility 指向 SF，App 侧指标不相关
      WHEN '${jank_responsibility}' = 'SF' THEN 'sf_composition'
      WHEN slice_dur > slice_critical_ms THEN 'slice'
      WHEN fence_ms > gpu_fence_critical_ms THEN 'gpu_fence'
      WHEN max_sched_ms > sched_max_critical_ms THEN 'sched_latency'
      WHEN main_q3 > 20 THEN 'cpu_contention'
      WHEN io_block_ms > io_block_critical_ms THEN 'io_blocking'
      WHEN total_sched_ms > total_sched_critical_ms THEN 'sched_latency'
      WHEN main_q4a > 20 THEN 'io_blocking'
      WHEN main_q4b > 30 THEN 'blocking'
      -- RenderThread 负载过重：RT 主动运行，非等待 GPU/SF
      WHEN render_q4a < 10 AND render_q4b < 20 AND COALESCE(shader_ms, 0) <= gpu_fence_warning_ms
        AND fence_ms <= gpu_fence_warning_ms
        THEN 'render_heavy'
      WHEN (render_q4a + render_q4b) > 50 THEN 'render_wait'
      WHEN COALESCE(shader_ms, 0) > gpu_fence_warning_ms THEN 'shader_compile'
      WHEN gc_overlap_ms > 1.0 THEN 'gc_pause'
      WHEN main_q2 > 50 THEN 'small_core'
      WHEN big_freq < 1200 AND big_freq > 0 THEN 'freq_limit'
      WHEN big_load_pct > 90 THEN 'cpu_overload'
      WHEN fence_ms > gpu_fence_warning_ms THEN 'gpu_fence'
      WHEN big_load_pct > 70 AND little_load_pct > 70 THEN 'cpu_overload'
      ELSE 'unknown'
    END as cause_type,
    slice_name,
    slice_dur,
    frame_budget_ms,
    ${dur_ms} as frame_dur_ms,
    '${jank_type}' as jank_type,
    '${jank_responsibility}' as jank_responsibility,
    max_sched_ms,
    total_sched_ms,
    main_q2,
    main_q3,
    main_q4a,
    main_q4b,
    big_freq,
    big_freq_peak,
    top_slice_little_pct,
    top_slice_big_pct,
    top_slice_runnable_pct,
    top_big_avg_freq_mhz,
    top_big_max_freq_mhz,
    ramp_to_high_ms,
    binder_overlap_ms,
    binder_sync_total_ms,
    big_load_pct,
    little_load_pct,
    io_block_ms,
    render_q4a,
    render_q4b,
    fence_ms,
    shader_ms,
    shader_count,
    sched_max_critical_ms,
    total_sched_critical_ms,
    io_block_critical_ms
  FROM classified
)
SELECT
  primary_cause,
  deep_reason,
  optimization_hint,
  reason_code,
  secondary_info,
  confidence,
  cause_type,
  slice_name,
  slice_dur,
  frame_budget_ms,
  main_q3 as main_q3_pct,
  main_q4a as main_q4a_pct,
  main_q4b as main_q4b_pct,
  render_q4a as render_q4a_pct,
  render_q4b as render_q4b_pct,
  max_sched_ms as main_max_sched_ms,
  io_block_ms as main_io_block_ms,
  fence_ms as gpu_fence_ms,
  frame_dur_ms,
  jank_type,
  CASE
    WHEN cause_type IN ('slice', 'blocking', 'io_blocking') THEN 'trigger'
    WHEN cause_type IN ('sched_latency', 'cpu_contention', 'small_core', 'freq_limit', 'cpu_overload') THEN 'supply'
    WHEN cause_type IN ('gpu_fence', 'render_wait', 'shader_compile') THEN 'amplification'
    WHEN cause_type = 'gc_pause' THEN 'trigger'
    WHEN cause_type = 'sf_composition' THEN 'amplification'
    WHEN cause_type = 'render_heavy' THEN 'trigger'
    ELSE 'unknown'
  END as mechanism_group,
  CASE
    WHEN reason_code = 'buffer_stuffing' THEN 'none'
    WHEN reason_code = 'sf_composition_slow' THEN 'none'
    WHEN reason_code = 'thermal_throttling' THEN 'thermal_throttle'
    WHEN reason_code IN ('binder_sync_blocking', 'io_page_cache_wait', 'uninterruptible_wait', 'lock_binder_wait', 'binder_timeout') THEN 'blocking_wait'
    WHEN reason_code = 'gc_jank' THEN 'gc_pause'
    WHEN reason_code = 'gc_pressure_cascade' THEN 'gc_pause'
    WHEN reason_code = 'small_core_placement' THEN 'core_placement'
    WHEN reason_code IN ('big_core_low_freq', 'freq_ramp_slow', 'cpu_max_limited') THEN 'frequency_insufficient'
    WHEN reason_code IN ('sched_delay_in_slice', 'scheduling_delay') THEN 'scheduling_delay'
    WHEN reason_code IN ('cpu_load_high', 'cpu_saturation') THEN 'load_high'
    WHEN reason_code = 'main_thread_file_io' THEN 'blocking_wait'
    WHEN reason_code = 'render_thread_heavy' THEN 'none'
    WHEN reason_code = 'shader_compile' THEN 'none'
    WHEN reason_code = 'workload_heavy' THEN 'none'
    WHEN io_block_ms > io_block_critical_ms OR main_q4a > 20 OR main_q4b > 30 THEN 'blocking_wait'
    WHEN big_freq < 1200 AND big_freq > 0 THEN 'frequency_insufficient'
    WHEN main_q2 > 50 THEN 'core_placement'
    WHEN max_sched_ms > sched_max_critical_ms OR total_sched_ms > total_sched_critical_ms OR main_q3 > 20 THEN 'scheduling_delay'
    WHEN big_load_pct > 90 OR (big_load_pct > 70 AND little_load_pct > 70) THEN 'load_high'
    WHEN cause_type = 'freq_limit' THEN 'frequency_insufficient'
    WHEN cause_type = 'small_core' THEN 'core_placement'
    WHEN cause_type IN ('sched_latency', 'cpu_contention') THEN 'scheduling_delay'
    WHEN cause_type = 'cpu_overload' THEN 'load_high'
    WHEN cause_type IN ('blocking', 'io_blocking') THEN 'blocking_wait'
    ELSE 'none'
  END as supply_constraint,
  CASE
    WHEN reason_code = 'buffer_stuffing' THEN 'buffer_pipeline'
    WHEN reason_code = 'sf_composition_slow' THEN 'sf_consumer'
    WHEN cause_type IN ('slice', 'blocking', 'io_blocking', 'sched_latency', 'cpu_contention', 'small_core', 'freq_limit', 'cpu_overload', 'gc_pause', 'render_heavy') THEN 'app_producer'
    WHEN cause_type IN ('gpu_fence', 'render_wait', 'shader_compile', 'sf_composition') THEN 'sf_consumer'
    ELSE 'unknown'
  END as trigger_layer,
  CASE
    WHEN reason_code = 'buffer_stuffing' THEN 'buffer_queue_backpressure'
    WHEN reason_code = 'sf_composition_slow' THEN 'sf_consumer_backpressure'
    WHEN cause_type = 'gpu_fence' THEN 'gpu_fence_wait'
    WHEN cause_type = 'shader_compile' THEN 'shader_compile_stall'
    WHEN cause_type IN ('render_wait', 'sf_composition') THEN 'render_pipeline_wait'
    WHEN cause_type = 'render_heavy' THEN 'app_deadline_miss'
    WHEN jank_responsibility = 'SF' THEN 'sf_consumer_backpressure'
    WHEN jank_responsibility = 'APP' THEN 'app_deadline_miss'
    ELSE 'unknown'
  END as amplification_path
FROM base_result
