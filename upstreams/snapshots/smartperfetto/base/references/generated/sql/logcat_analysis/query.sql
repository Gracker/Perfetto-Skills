-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/logcat_analysis.skill.yaml
-- Source SHA-256: 8c0018e6416eba29e18bcde7319b929fcc73db350ceff3d87b86e2e2b66e0f60
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH tagged AS (
  SELECT
    ts,
    prio,
    tag,
    msg,
    CASE
      WHEN LOWER(COALESCE(tag, '')) GLOB '*inputdispatcher*'
        OR LOWER(COALESCE(msg, '')) GLOB '*input dispatching timed out*'
        THEN 'input_dispatch'
      WHEN LOWER(COALESCE(msg, '')) GLOB '*no focused window*'
        OR LOWER(COALESCE(msg, '')) GLOB '*does not have a focused window*'
        THEN 'no_focus_window'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*anrmanager*'
        OR LOWER(COALESCE(msg, '')) GLOB '*anr in *'
        THEN 'anrmanager'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*activitymanager*'
        OR LOWER(COALESCE(tag, '')) GLOB '*activitytaskmanager*'
        THEN 'activity_manager'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*windowmanager*'
        THEN 'window_manager'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*broadcastqueue*'
        OR LOWER(COALESCE(msg, '')) GLOB '*broadcast of intent*'
        THEN 'broadcast_timeout'
      WHEN LOWER(COALESCE(msg, '')) GLOB '*executing service*'
        OR LOWER(COALESCE(msg, '')) GLOB '*start foreground service*'
        OR LOWER(COALESCE(tag, '')) GLOB '*activeservices*'
        THEN 'service_timeout'
      WHEN LOWER(COALESCE(msg, '')) GLOB '*contentprovider not responding*'
        OR LOWER(COALESCE(msg, '')) GLOB '*content provider not responding*'
        THEN 'provider_timeout'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*jobscheduler*'
        OR LOWER(COALESCE(msg, '')) GLOB '*jobservice*'
        THEN 'job_scheduler'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*watchdog*'
        OR LOWER(COALESCE(msg, '')) GLOB '*watchdog*'
        THEN 'watchdog'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*lmkd*'
        OR LOWER(COALESCE(tag, '')) GLOB '*lowmemorykiller*'
        OR LOWER(COALESCE(msg, '')) GLOB '*low memory*'
        OR LOWER(COALESCE(msg, '')) GLOB '*pressure*'
        THEN 'memory_pressure'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*art*'
        OR LOWER(COALESCE(msg, '')) GLOB '*gc*'
        THEN 'gc_or_art'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*choreographer*'
        OR LOWER(COALESCE(tag, '')) GLOB '*surfaceflinger*'
        OR LOWER(COALESCE(msg, '')) GLOB '*skipped frames*'
        THEN 'render_or_frame'
      WHEN LOWER(COALESCE(tag, '')) GLOB '*strictmode*'
        OR LOWER(COALESCE(tag, '')) GLOB '*binder*'
        OR LOWER(COALESCE(msg, '')) GLOB '*anr*'
        OR LOWER(COALESCE(msg, '')) GLOB '*not responding*'
        THEN 'anr_related'
      ELSE 'other'
    END AS signal_type
  FROM android_logs
  WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
scoped AS (
  SELECT
    tagged.*,
    CASE
      WHEN '${package|}' <> ''
        AND (
          LOWER(COALESCE(msg, '')) LIKE '%' || LOWER('${package|}') || '%'
          OR LOWER(COALESCE(tag, '')) LIKE '%' || LOWER('${package|}') || '%'
        )
        THEN 1 ELSE 0
    END AS package_match
  FROM tagged
)
SELECT
  printf('%d', ts) as ts_str,
  CASE prio
    WHEN 4 THEN 'INFO'
    WHEN 5 THEN 'WARN'
    WHEN 6 THEN 'ERROR'
    WHEN 7 THEN 'FATAL'
    ELSE 'INFO'
  END as prio,
  tag,
  signal_type,
  CASE
    WHEN '${package|}' = '' THEN 'global'
    WHEN package_match = 1 THEN 'target_scoped'
    ELSE 'global_context'
  END AS evidence_scope,
  SUBSTR(msg, 1, 200) as msg_preview
FROM scoped
WHERE (prio >= 5 OR (prio >= 4 AND signal_type <> 'other'))
  AND (
    '${package|}' = ''
    OR package_match = 1
    OR (prio >= 5 AND signal_type <> 'other')
  )
ORDER BY ts
LIMIT 50
