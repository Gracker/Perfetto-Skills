-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/startup_analysis.skill.yaml
-- Source SHA-256: 96b682a4206afafddcfb6e63c60e842921381a674744f413881a609e862ef41b
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH filtered AS (
  SELECT
    s.startup_id,
    s.startup_type,
    s.package,
    s.ts,
    s.dur,
    s.dur / 1e6 as dur_ms,
    CASE
      WHEN ttd.time_to_initial_display IS NULL OR ttd.time_to_initial_display <= 0 THEN NULL
      ELSE ttd.time_to_initial_display / 1e6
    END as ttid_ms,
    CASE
      WHEN ttd.time_to_full_display IS NULL OR ttd.time_to_full_display <= 0 THEN NULL
      ELSE ttd.time_to_full_display / 1e6
    END as ttfd_ms
  FROM android_startups s
  LEFT JOIN android_startup_time_to_display ttd USING (startup_id)
  WHERE (s.package GLOB '${package}*' OR '${package}' = '')
    AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
),
-- Detect key slices to validate startup_type classification.
-- Uses android_startup_threads (stdlib) + direct slice JOIN with OVERLAP
-- time filter. bindApplication can start before the startup window.
startup_type_signals AS (
  SELECT
    st.startup_id,
    MAX(CASE WHEN sl.name = 'bindApplication' THEN 1 ELSE 0 END) as has_bind_app,
    MAX(CASE WHEN sl.name GLOB 'performCreate:*' THEN 1 ELSE 0 END) as has_perform_create,
    MAX(CASE WHEN sl.name GLOB 'handleRelaunchActivity*'
             OR sl.name GLOB 'relaunchActivity*' THEN 1 ELSE 0 END) as has_relaunch
  FROM android_startup_threads st
  JOIN thread_track tt ON tt.utid = st.utid
  JOIN slice sl ON sl.track_id = tt.id
  WHERE st.is_main_thread = 1
    AND st.startup_id IN (SELECT startup_id FROM filtered)
    AND sl.ts + sl.dur > st.ts AND sl.ts < st.ts + st.dur
    AND (sl.name = 'bindApplication' OR sl.name GLOB 'performCreate:*'
         OR sl.name GLOB 'handleRelaunchActivity*' OR sl.name GLOB 'relaunchActivity*')
  GROUP BY st.startup_id
),
flags AS (
  SELECT
    f.startup_id,
    CASE WHEN f.dur <= 0 THEN 1 ELSE 0 END as b_invalid_duration,
    CASE WHEN f.dur_ms >= 200 AND f.ttid_ms IS NOT NULL AND f.ttid_ms < 10 THEN 1 ELSE 0 END as w_ttid_small,
    CASE WHEN f.dur_ms >= 200 AND f.ttfd_ms IS NOT NULL AND f.ttfd_ms < 10 THEN 1 ELSE 0 END as w_ttfd_small,
    CASE WHEN f.ttid_ms IS NOT NULL AND f.ttid_ms > f.dur_ms + 50 THEN 1 ELSE 0 END as w_ttid_gt_dur,
    CASE WHEN f.ttfd_ms IS NOT NULL AND f.ttfd_ms > f.dur_ms + 50 THEN 1 ELSE 0 END as w_ttfd_gt_dur,
    CASE WHEN f.ttid_ms IS NOT NULL AND f.ttfd_ms IS NOT NULL AND f.ttfd_ms < f.ttid_ms THEN 1 ELSE 0 END as w_ttfd_lt_ttid,
    CASE
      WHEN COALESCE(sts.has_bind_app, 0) = 1 AND f.startup_type != 'cold' THEN 1
      WHEN COALESCE(sts.has_perform_create, 0) = 1 AND COALESCE(sts.has_bind_app, 0) = 0 AND f.startup_type != 'warm' THEN 1
      WHEN COALESCE(sts.has_relaunch, 0) = 1 AND f.startup_type != 'warm' THEN 1
      ELSE 0
    END as w_type_reclassified
  FROM filtered f
  LEFT JOIN startup_type_signals sts USING (startup_id)
),
agg AS (
  SELECT
    COUNT(*) as sample_count,
    COALESCE(SUM(b_invalid_duration), 0) as blocker_count,
    COALESCE(SUM(w_ttid_small), 0) +
      COALESCE(SUM(w_ttfd_small), 0) +
      COALESCE(SUM(w_ttid_gt_dur), 0) +
      COALESCE(SUM(w_ttfd_gt_dur), 0) +
      COALESCE(SUM(w_ttfd_lt_ttid), 0) +
      COALESCE(SUM(w_type_reclassified), 0) as warning_count,
    MAX(CASE WHEN b_invalid_duration = 1 THEN 1 ELSE 0 END) as has_invalid_duration,
    MAX(CASE WHEN w_ttid_small = 1 THEN 1 ELSE 0 END) as has_ttid_small,
    MAX(CASE WHEN w_ttfd_small = 1 THEN 1 ELSE 0 END) as has_ttfd_small,
    MAX(CASE WHEN w_ttid_gt_dur = 1 THEN 1 ELSE 0 END) as has_ttid_gt_dur,
    MAX(CASE WHEN w_ttfd_gt_dur = 1 THEN 1 ELSE 0 END) as has_ttfd_gt_dur,
    MAX(CASE WHEN w_ttfd_lt_ttid = 1 THEN 1 ELSE 0 END) as has_ttfd_lt_ttid,
    MAX(CASE WHEN w_type_reclassified = 1 THEN 1 ELSE 0 END) as has_type_reclassified
  FROM flags
)
SELECT
  sample_count,
  blocker_count,
  warning_count,
  CASE
    WHEN blocker_count > 0 THEN 'BLOCKER'
    WHEN warning_count > 0 THEN 'WARN'
    ELSE 'PASS'
  END as quality_status,
  TRIM(
    (CASE WHEN has_invalid_duration = 1 THEN 'R001_INVALID_DURATION,' ELSE '' END) ||
    (CASE WHEN has_ttid_small = 1 THEN 'R008_TTID_SUSPICIOUSLY_SMALL,' ELSE '' END) ||
    (CASE WHEN has_ttfd_small = 1 THEN 'R008_TTFD_SUSPICIOUSLY_SMALL,' ELSE '' END) ||
    (CASE WHEN has_ttid_gt_dur = 1 THEN 'R008_TTID_GT_DUR,' ELSE '' END) ||
    (CASE WHEN has_ttfd_gt_dur = 1 THEN 'R008_TTFD_GT_DUR,' ELSE '' END) ||
    (CASE WHEN has_ttfd_lt_ttid = 1 THEN 'R008_TTFD_LT_TTID,' ELSE '' END) ||
    (CASE WHEN has_type_reclassified = 1 THEN 'R009_TYPE_RECLASSIFIED,' ELSE '' END),
    ','
  ) as issue_codes,
  CASE
    WHEN blocker_count > 0 THEN '检测到阻断级数据问题，已停止启动深挖'
    WHEN has_type_reclassified = 1 AND warning_count = 1 THEN '启动类型已修正（基于 bindApplication/performCreate 存在性校验，原始分类不一致），评级已按修正后类型计算'
    WHEN warning_count > 0 THEN '检测到可疑指标，结论需谨慎解读'
    ELSE '数据质量通过，允许进入深度分析'
  END as quality_summary
FROM agg
