-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/process_identity_resolver.skill.yaml
-- Source SHA-256: 0825f2ccd3b390e08777718e3eab70f65d0c162625007baded0f9cc0093a8500
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

INCLUDE PERFETTO MODULE android.process_metadata;
INCLUDE PERFETTO MODULE android.frames.timeline;
INCLUDE PERFETTO MODULE android.oom_adjuster;
INCLUDE PERFETTO MODULE android.battery_stats;

WITH
raw_input AS (
  SELECT
    NULLIF(COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', '')), '') AS target_name,
    NULLIF('${thread_name|}', '') AS target_thread,
    ${upid} AS target_upid,
    ${pid} AS target_pid,
    COALESCE(${start_ts}, trace_start()) AS raw_start_ts,
    COALESCE(${end_ts}, trace_end()) AS raw_end_ts,
    MIN(MAX(COALESCE(${max_rows|20}, 20), 1), 100) AS max_rows
),
input AS (
  SELECT
    target_name,
    target_thread,
    target_upid,
    target_pid,
    MIN(raw_start_ts, raw_end_ts) AS start_ts,
    MAX(raw_start_ts, raw_end_ts) AS end_ts,
    max_rows
  FROM raw_input
),
process_base AS (
  SELECT
    p.upid,
    p.pid,
    p.name AS process_name,
    p.cmdline,
    p.uid AS unix_uid,
    p.android_appid,
    p.start_ts,
    p.end_ts,
    m.process_name AS metadata_process_name,
    m.package_name,
    m.uid AS app_uid,
    m.shared_uid,
    m.is_kernel_task,
    CASE
      WHEN m.is_kernel_task = 1 THEN 1
      WHEN p.name IN ('system_server', 'surfaceflinger', 'zygote', 'zygote64', 'init') THEN 1
      WHEN p.name GLOB '/system/bin/*' THEN 1
      WHEN p.name GLOB '/system_ext/bin/*' THEN 1
      WHEN p.name GLOB '/vendor/bin/*' THEN 1
      WHEN p.name GLOB '/odm/bin/*' THEN 1
      WHEN p.name GLOB '/apex/*' THEN 1
      WHEN p.name GLOB 'com.android.systemui*' THEN 1
      WHEN p.name GLOB 'com.android.launcher*' THEN 1
      WHEN p.name GLOB 'com.google.android.apps.nexuslauncher*' THEN 1
      WHEN p.name GLOB 'com.miui.home*' THEN 1
      WHEN p.name GLOB 'com.huawei.android.launcher*' THEN 1
      WHEN p.name GLOB 'com.oppo.launcher*' THEN 1
      WHEN p.name GLOB 'com.vivo.launcher*' THEN 1
      WHEN p.name GLOB 'com.sec.android.app.launcher*' THEN 1
      WHEN p.name GLOB 'com.google.android.inputmethod*' THEN 1
      WHEN p.name GLOB 'com.android.inputmethod*' THEN 1
      ELSE 0
    END AS is_system_like_process
  FROM process p
  LEFT JOIN android_process_metadata m USING (upid)
),
thread_summary AS (
  SELECT
    t.upid,
    COUNT(*) AS thread_count,
    MAX(CASE WHEN t.is_main_thread = 1 OR t.tid = p.pid THEN 1 ELSE 0 END) AS has_main_thread,
    MAX(CASE
      WHEN t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1')
        OR t.name GLOB '[0-9]*.ui'
        OR t.name GLOB '[0-9]*.raster'
        OR t.name GLOB 'Cr*Main'
      THEN 1 ELSE 0 END) AS has_rendering_thread,
    MAX(CASE
      WHEN input.target_thread IS NOT NULL
        AND COALESCE(t.name, '') GLOB '*' || input.target_thread || '*'
      THEN 1
      WHEN LOWER(COALESCE(input.target_thread, '')) IN ('main', 'ui', 'app_main')
        AND (t.is_main_thread = 1 OR t.tid = p.pid)
      THEN 1
      WHEN LOWER(COALESCE(input.target_thread, '')) IN ('renderthread', 'render_thread', 'render')
        AND (
          t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1')
          OR t.name GLOB '[0-9]*.ui'
          OR t.name GLOB '[0-9]*.raster'
          OR t.name GLOB 'Cr*Main'
        )
      THEN 1 ELSE 0 END) AS target_thread_match,
    GROUP_CONCAT(DISTINCT CASE
      WHEN t.is_main_thread = 1 OR t.tid = p.pid
        OR t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1')
        OR t.name GLOB '[0-9]*.ui'
        OR t.name GLOB '[0-9]*.raster'
        OR t.name GLOB 'Cr*Main'
      THEN COALESCE(t.name, '<unnamed>')
    END) AS key_thread_names
  FROM thread t
  JOIN process p USING (upid)
  CROSS JOIN input
  GROUP BY t.upid
),
thread_identity_candidates AS (
  SELECT
    t.upid,
    t.utid,
    t.tid,
    COALESCE(t.name, '<unnamed>') AS thread_name,
    CASE
      WHEN t.is_main_thread = 1 OR t.tid = p.pid THEN 'app_main'
      WHEN t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1')
        OR t.name GLOB '[0-9]*.ui'
        OR t.name GLOB '[0-9]*.raster'
        OR t.name GLOB 'Cr*Main'
      THEN 'render_thread'
      ELSE 'unknown'
    END AS thread_role,
    CASE
      WHEN input.target_thread IS NOT NULL
        AND COALESCE(t.name, '') GLOB '*' || input.target_thread || '*'
      THEN 1
      WHEN LOWER(COALESCE(input.target_thread, '')) IN ('main', 'ui', 'app_main')
        AND (t.is_main_thread = 1 OR t.tid = p.pid)
      THEN 1
      WHEN LOWER(COALESCE(input.target_thread, '')) IN ('renderthread', 'render_thread', 'render')
        AND (
          t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1')
          OR t.name GLOB '[0-9]*.ui'
          OR t.name GLOB '[0-9]*.raster'
          OR t.name GLOB 'Cr*Main'
        )
      THEN 1 ELSE 0
    END AS thread_target_matched,
    ROW_NUMBER() OVER (
      PARTITION BY t.upid
      ORDER BY
        CASE
          WHEN input.target_thread IS NOT NULL
            AND COALESCE(t.name, '') GLOB '*' || input.target_thread || '*'
          THEN 0
          WHEN LOWER(COALESCE(input.target_thread, '')) IN ('main', 'ui', 'app_main')
            AND (t.is_main_thread = 1 OR t.tid = p.pid)
          THEN 0
          WHEN LOWER(COALESCE(input.target_thread, '')) IN ('renderthread', 'render_thread', 'render')
            AND (
              t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1')
              OR t.name GLOB '[0-9]*.ui'
              OR t.name GLOB '[0-9]*.raster'
              OR t.name GLOB 'Cr*Main'
            )
          THEN 0 ELSE 1
        END,
        CASE WHEN t.is_main_thread = 1 OR t.tid = p.pid THEN 0 ELSE 1 END,
        CASE
          WHEN t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1')
            OR t.name GLOB '[0-9]*.ui'
            OR t.name GLOB '[0-9]*.raster'
            OR t.name GLOB 'Cr*Main'
          THEN 0 ELSE 1
        END,
        t.utid
    ) AS thread_rank
  FROM thread t
  JOIN process p USING (upid)
  CROSS JOIN input
  WHERE
    (input.target_thread IS NOT NULL AND COALESCE(t.name, '') GLOB '*' || input.target_thread || '*')
    OR (LOWER(COALESCE(input.target_thread, '')) IN ('main', 'ui', 'app_main') AND (t.is_main_thread = 1 OR t.tid = p.pid))
    OR (LOWER(COALESCE(input.target_thread, '')) IN ('renderthread', 'render_thread', 'render') AND (
      t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1')
      OR t.name GLOB '[0-9]*.ui'
      OR t.name GLOB '[0-9]*.raster'
      OR t.name GLOB 'Cr*Main'
    ))
    OR t.is_main_thread = 1
    OR t.tid = p.pid
    OR t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1')
    OR t.name GLOB '[0-9]*.ui'
    OR t.name GLOB '[0-9]*.raster'
    OR t.name GLOB 'Cr*Main'
),
thread_identity AS (
  SELECT
    upid,
    utid AS thread_utid,
    tid AS thread_tid,
    thread_name,
    thread_role,
    thread_target_matched
  FROM thread_identity_candidates
  WHERE thread_rank = 1
),
frame_rows AS (
  SELECT
    a.upid,
    a.ts,
    IIF(a.dur = -1, trace_end() - a.ts, a.dur) AS effective_dur,
    a.jank_type,
    a.layer_name,
    CASE
      WHEN a.layer_name LIKE 'TX - %/%'
        THEN SUBSTR(a.layer_name, 6, INSTR(SUBSTR(a.layer_name, 6), '/') - 1)
      WHEN a.layer_name LIKE 'TX - %'
        THEN SUBSTR(a.layer_name, 6)
      ELSE NULL
    END AS layer_package
  FROM actual_frame_timeline_slice a
),
frame_summary AS (
  SELECT
    fr.upid,
    COUNT(*) AS frame_rows,
    SUM(CASE WHEN fr.jank_type IS NOT NULL AND fr.jank_type != 'None' THEN 1 ELSE 0 END) AS jank_rows,
    MAX(CASE
      WHEN input.target_name IS NOT NULL
        AND COALESCE(fr.layer_package, '') GLOB '*' || input.target_name || '*'
      THEN 1 ELSE 0 END) AS layer_target_match,
    GROUP_CONCAT(DISTINCT fr.layer_package) AS layer_packages
  FROM frame_rows fr
  CROSS JOIN input
  WHERE fr.upid IS NOT NULL
    AND fr.effective_dur > 0
    AND fr.ts < input.end_ts
    AND fr.ts + fr.effective_dur > input.start_ts
  GROUP BY fr.upid
),
oom_rows AS (
  SELECT
    upid,
    ts,
    IIF(dur = -1, trace_end() - ts, dur) AS effective_dur,
    score
  FROM android_oom_adj_intervals
),
oom_summary AS (
  SELECT
    o.upid,
    SUM(MIN(o.ts + o.effective_dur, input.end_ts) - MAX(o.ts, input.start_ts)) AS foreground_ns,
    COUNT(*) AS foreground_events
  FROM oom_rows o
  CROSS JOIN input
  WHERE o.effective_dur > 0
    AND o.score <= 0
    AND o.score > -900
    AND o.ts < input.end_ts
    AND o.ts + o.effective_dur > input.start_ts
  GROUP BY o.upid
),
battery_top AS (
  SELECT
    str_value AS package_name,
    SUM(MIN(ts + safe_dur, input.end_ts) - MAX(ts, input.start_ts)) AS top_ns,
    COUNT(*) AS top_events
  FROM android_battery_stats_event_slices
  CROSS JOIN input
  WHERE track_name = 'battery_stats.top'
    AND str_value IS NOT NULL
    AND str_value != ''
    AND safe_dur > 0
    AND ts < input.end_ts
    AND ts + safe_dur > input.start_ts
  GROUP BY str_value
),
candidate_signals AS (
  SELECT
    pb.*,
    COALESCE(ts.thread_count, 0) AS thread_count,
    COALESCE(ts.has_main_thread, 0) AS has_main_thread,
    COALESCE(ts.has_rendering_thread, 0) AS has_rendering_thread,
    COALESCE(ts.target_thread_match, 0) AS target_thread_match,
    ts.key_thread_names,
    ti.thread_utid,
    ti.thread_tid,
    ti.thread_name,
    ti.thread_role,
    COALESCE(ti.thread_target_matched, 0) AS thread_target_matched,
    COALESCE(fs.frame_rows, 0) AS frame_rows,
    COALESCE(fs.jank_rows, 0) AS jank_rows,
    COALESCE(fs.layer_target_match, 0) AS layer_target_match,
    fs.layer_packages,
    COALESCE(os.foreground_ns, 0) AS foreground_ns,
    COALESCE(os.foreground_events, 0) AS foreground_events,
    COALESCE(bt.top_ns, 0) AS battery_top_ns,
    COALESCE(bt.top_events, 0) AS battery_top_events,
    input.target_name,
    input.target_thread,
    input.target_upid,
    input.target_pid,
    input.max_rows
  FROM process_base pb
  CROSS JOIN input
  LEFT JOIN thread_summary ts USING (upid)
  LEFT JOIN thread_identity ti USING (upid)
  LEFT JOIN frame_summary fs USING (upid)
  LEFT JOIN oom_summary os USING (upid)
  LEFT JOIN battery_top bt
    ON bt.package_name = pb.package_name
    OR bt.package_name = pb.metadata_process_name
    OR bt.package_name = pb.process_name
    OR bt.package_name = pb.cmdline
),
scored_base AS (
  SELECT
    *,
    COALESCE(package_name, metadata_process_name, cmdline, process_name, '<unknown>') AS canonical_package_name,
    COALESCE(process_name, metadata_process_name, package_name, cmdline, '<unknown>') AS recommended_process_name_param,
    (
      CASE WHEN target_upid IS NOT NULL AND upid = target_upid THEN 100 ELSE 0 END +
      CASE WHEN target_pid IS NOT NULL AND pid = target_pid THEN 35 ELSE 0 END +
      CASE WHEN target_name IS NOT NULL AND COALESCE(package_name, '') = target_name THEN 50 ELSE 0 END +
      CASE WHEN target_name IS NOT NULL AND COALESCE(metadata_process_name, '') = target_name THEN 40 ELSE 0 END +
      CASE WHEN target_name IS NOT NULL AND COALESCE(process_name, '') = target_name THEN 35 ELSE 0 END +
      CASE WHEN target_name IS NOT NULL AND COALESCE(cmdline, '') = target_name THEN 35 ELSE 0 END +
      CASE WHEN target_name IS NOT NULL AND COALESCE(package_name, '') GLOB target_name || '*' THEN 25 ELSE 0 END +
      CASE WHEN target_name IS NOT NULL AND COALESCE(metadata_process_name, '') GLOB target_name || '*' THEN 20 ELSE 0 END +
      CASE WHEN target_name IS NOT NULL AND COALESCE(process_name, '') GLOB target_name || '*' THEN 20 ELSE 0 END +
      CASE WHEN target_name IS NOT NULL AND COALESCE(cmdline, '') GLOB target_name || '*' THEN 20 ELSE 0 END +
      CASE WHEN target_name IS NOT NULL AND layer_target_match = 1 AND is_system_like_process = 0 THEN 15 ELSE 0 END +
      CASE WHEN target_thread IS NOT NULL AND target_thread_match = 1 THEN 20 ELSE 0 END +
      CASE WHEN target_name IS NULL AND target_upid IS NULL AND target_pid IS NULL AND target_thread IS NOT NULL AND target_thread_match = 1 THEN 35 ELSE 0 END
    ) AS identity_score,
    (
      CASE WHEN frame_rows > 0 THEN 15 ELSE 0 END +
      CASE WHEN jank_rows > 0 THEN 10 ELSE 0 END +
      CASE WHEN foreground_ns > 0 THEN 15 ELSE 0 END +
      CASE WHEN battery_top_ns > 0 THEN 20 ELSE 0 END +
      CASE WHEN has_main_thread = 1 THEN 5 ELSE 0 END +
      CASE WHEN has_rendering_thread = 1 THEN 5 ELSE 0 END
    ) AS activity_score,
    TRIM(
      (CASE WHEN target_upid IS NOT NULL AND upid = target_upid THEN 'upid,' ELSE '' END) ||
      (CASE WHEN target_pid IS NOT NULL AND pid = target_pid THEN 'pid,' ELSE '' END) ||
      (CASE WHEN target_name IS NOT NULL AND COALESCE(package_name, '') GLOB target_name || '*' THEN 'android_process_metadata.package_name,' ELSE '' END) ||
      (CASE WHEN target_name IS NOT NULL AND COALESCE(metadata_process_name, '') GLOB target_name || '*' THEN 'android_process_metadata.process_name,' ELSE '' END) ||
      (CASE WHEN target_name IS NOT NULL AND COALESCE(process_name, '') GLOB target_name || '*' THEN 'process.name,' ELSE '' END) ||
      (CASE WHEN target_name IS NOT NULL AND COALESCE(cmdline, '') GLOB target_name || '*' THEN 'process.cmdline,' ELSE '' END) ||
      (CASE WHEN layer_target_match = 1 AND is_system_like_process = 0 THEN 'frame_timeline.layer,' ELSE '' END) ||
      (CASE WHEN target_thread_match = 1 THEN 'thread.name,' ELSE '' END),
      ','
    ) AS target_match_sources
  FROM candidate_signals
),
scored AS (
  SELECT
    *,
    CASE
      WHEN target_name IS NULL
        AND target_thread IS NULL
        AND target_upid IS NULL
        AND target_pid IS NULL
        THEN CASE
          WHEN frame_rows > 0 OR foreground_ns > 0 OR battery_top_ns > 0 THEN activity_score
          ELSE 0
        END
      WHEN identity_score > 0 THEN identity_score + MIN(20, activity_score)
      ELSE 0
    END AS raw_score,
    TRIM(
      (CASE WHEN battery_top_ns > 0 THEN 'battery_stats.top,' ELSE '' END) ||
      (CASE WHEN foreground_ns > 0 THEN 'oom_adj.foreground,' ELSE '' END) ||
      (CASE WHEN layer_target_match = 1 THEN 'frame_timeline.layer,' ELSE '' END) ||
      (CASE WHEN frame_rows > 0 THEN 'frame_timeline.upid,' ELSE '' END),
      ','
    ) AS supporting_sources
  FROM scored_base
),
ranked AS (
  SELECT
    ROW_NUMBER() OVER (
      ORDER BY
        CASE
          WHEN target_name IS NOT NULL
            OR target_thread IS NOT NULL
            OR target_upid IS NOT NULL
            OR target_pid IS NOT NULL
            THEN 0
          ELSE is_system_like_process
        END ASC,
        MIN(100, raw_score) DESC,
        frame_rows DESC,
        foreground_ns DESC,
        battery_top_ns DESC,
        upid ASC
    ) AS rank,
    *
  FROM scored
  WHERE is_kernel_task IS NULL OR is_kernel_task = 0
)
SELECT
  rank,
  MIN(100, raw_score) AS confidence_score,
  CASE
    WHEN (target_name IS NOT NULL OR target_thread IS NOT NULL OR target_upid IS NOT NULL OR target_pid IS NOT NULL)
      AND MIN(100, raw_score) >= 80 THEN 'confirmed'
    WHEN (target_name IS NOT NULL OR target_thread IS NOT NULL OR target_upid IS NOT NULL OR target_pid IS NOT NULL)
      AND MIN(100, raw_score) >= 50 THEN 'probable'
    WHEN (target_name IS NOT NULL OR target_thread IS NOT NULL OR target_upid IS NOT NULL OR target_pid IS NOT NULL)
      AND MIN(100, raw_score) > 0 THEN 'weak_match'
    WHEN target_name IS NULL
      AND target_thread IS NULL
      AND target_upid IS NULL
      AND target_pid IS NULL
      AND (battery_top_ns > 0 OR foreground_ns > 0 OR frame_rows > 0) THEN 'foreground_candidate'
    ELSE 'context'
  END AS identity_status,
  canonical_package_name,
  recommended_process_name_param,
  upid,
  pid,
  process_name,
  metadata_process_name,
  package_name,
  cmdline,
  target_match_sources,
  supporting_sources,
  frame_rows,
  jank_rows,
  ROUND(foreground_ns / 1e6, 2) AS foreground_ms,
  ROUND(battery_top_ns / 1e6, 2) AS battery_top_ms,
  thread_count,
  key_thread_names,
  thread_utid,
  thread_tid,
  thread_name,
  thread_role,
  thread_target_matched,
  layer_packages,
  CASE
    WHEN package_name IS NOT NULL
      AND process_name IS NOT NULL
      AND process_name NOT GLOB package_name || '*'
      AND COALESCE(cmdline, '') NOT GLOB package_name || '*'
      THEN 'process.name 与 package_name 不一致；下游旧 Skill 应传 recommended_process_name_param，报告中保留 canonical_package_name'
    WHEN target_name IS NOT NULL
      AND target_match_sources NOT LIKE '%process.name%'
      AND (target_match_sources LIKE '%package_name%' OR target_match_sources LIKE '%cmdline%' OR target_match_sources LIKE '%layer%')
      THEN '目标未命中 process.name，但命中了 metadata/cmdline/layer；不要只按 process.name 判断'
    WHEN shared_uid = 1
      THEN 'shared UID，包名归属可能需要结合 process/cmdline/线程继续确认'
    WHEN target_name IS NOT NULL AND MIN(100, raw_score) = 0
      THEN '未找到目标匹配；建议放宽包名、改用线程名或先查看全量候选'
    ELSE 'ok'
  END AS identity_warning
FROM ranked
WHERE rank <= (SELECT max_rows FROM input)
  AND raw_score > 0
  AND (
    target_name IS NOT NULL
    OR target_thread IS NOT NULL
    OR target_upid IS NOT NULL
    OR target_pid IS NOT NULL
    OR is_system_like_process = 0
  )
ORDER BY rank;
