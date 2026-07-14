-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: e48c73408b2775bed099612d32832cde9f70ca33cd1cc462e0275b1454588359
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} AS start_ts,
    ${anr_ts} AS anr_ts,
    ${anr_ts} + 5000000000 AS end_ts
),
tagged AS (
  SELECT
    l.*,
    CASE
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*inputdispatcher*' OR LOWER(COALESCE(l.msg, '')) GLOB '*input dispatch*' THEN 'input_dispatch'
      WHEN LOWER(COALESCE(l.msg, '')) GLOB '*no focused window*' OR LOWER(COALESCE(l.msg, '')) GLOB '*no focus window*' THEN 'no_focus_window'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*anrmanager*' THEN 'anrmanager'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*activitymanager*' OR LOWER(COALESCE(l.tag, '')) GLOB '*activitytaskmanager*' THEN 'activity_manager'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*windowmanager*' THEN 'window_manager'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*broadcastqueue*' OR LOWER(COALESCE(l.msg, '')) GLOB '*broadcast*timeout*' THEN 'broadcast_timeout'
      WHEN LOWER(COALESCE(l.msg, '')) GLOB '*executing service*' OR LOWER(COALESCE(l.msg, '')) GLOB '*foreground service*' THEN 'service_timeout'
      WHEN LOWER(COALESCE(l.msg, '')) GLOB '*contentprovider*' OR LOWER(COALESCE(l.msg, '')) GLOB '*provider not responding*' THEN 'provider_timeout'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*jobscheduler*' OR LOWER(COALESCE(l.msg, '')) GLOB '*jobservice*' THEN 'job_scheduler'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*watchdog*' OR LOWER(COALESCE(l.msg, '')) GLOB '*system_server*watchdog*' THEN 'watchdog'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*lmkd*' OR LOWER(COALESCE(l.tag, '')) GLOB '*lowmemorykiller*' OR LOWER(COALESCE(l.msg, '')) GLOB '*lowmemory*' THEN 'memory_pressure'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*art*' OR LOWER(COALESCE(l.msg, '')) GLOB '*gc*' THEN 'gc_or_art'
      WHEN LOWER(COALESCE(l.tag, '')) GLOB '*strictmode*'
        OR LOWER(COALESCE(l.tag, '')) GLOB '*binder*'
        OR LOWER(COALESCE(l.msg, '')) GLOB '*anr*'
        OR LOWER(COALESCE(l.msg, '')) GLOB '*not responding*'
        THEN 'anr_related'
      ELSE 'other'
    END AS signal_type
  FROM android_logs l
),
scoped AS (
  SELECT
    l.*,
    CASE
      WHEN '${process_name}' <> ''
        AND LOWER(COALESCE(l.msg, '')) LIKE '%' || LOWER('${process_name}') || '%'
        THEN 1 ELSE 0
    END AS process_match,
    CASE
      WHEN '${component}' <> ''
        AND LOWER(COALESCE(l.msg, '')) LIKE '%' || LOWER('${component}') || '%'
        THEN 1 ELSE 0
    END AS component_match,
    CASE
      WHEN '${intent}' <> ''
        AND LOWER(COALESCE(l.msg, '')) LIKE '%' || LOWER('${intent}') || '%'
        THEN 1 ELSE 0
    END AS intent_match,
    CASE
      WHEN '${error_id}' <> ''
        AND LOWER(COALESCE(l.msg, '')) LIKE '%' || LOWER('${error_id}') || '%'
        THEN 1 ELSE 0
    END AS error_match,
    CASE
      WHEN l.signal_type IN (
        'input_dispatch',
        'no_focus_window',
        'anrmanager',
        'activity_manager',
        'window_manager',
        'broadcast_timeout',
        'service_timeout',
        'provider_timeout',
        'job_scheduler',
        'watchdog',
        'memory_pressure',
        'gc_or_art',
        'anr_related'
      ) THEN 1 ELSE 0
    END AS global_signal_match
  FROM tagged l
)
SELECT
  '${error_id}' AS error_id,
  ROUND((l.ts - aw.anr_ts) / 1e6, 2) AS relation_to_anr_ms,
  CASE
    WHEN l.ts < aw.anr_ts THEN 'pre_anr'
    WHEN l.ts <= aw.anr_ts + 1000000000 THEN 'dump_or_trigger'
    ELSE 'post_anr'
  END AS phase,
  CASE
    WHEN l.ts <= aw.anr_ts
      AND (l.error_match = 1 OR l.component_match = 1 OR l.intent_match = 1)
      AND (
        l.global_signal_match = 1
        OR (l.prio >= 5 AND l.signal_type <> 'other')
      )
      THEN 1
    ELSE 0
  END AS root_cause_eligible,
  l.signal_type,
  CASE
    WHEN l.error_match = 1 OR l.component_match = 1 OR l.intent_match = 1 THEN 'event_scoped'
    WHEN l.process_match = 1 THEN 'target_process_context'
    ELSE 'global_context'
  END AS evidence_scope,
  CASE l.prio
    WHEN 4 THEN 'INFO'
    WHEN 5 THEN 'WARN'
    WHEN 6 THEN 'ERROR'
    WHEN 7 THEN 'FATAL'
    ELSE CAST(l.prio AS TEXT)
  END AS prio,
  l.tag,
  SUBSTR(l.msg, 1, 220) AS msg_preview
FROM scoped l
CROSS JOIN anr_window aw
WHERE l.ts >= aw.start_ts
  AND l.ts <= aw.end_ts
  AND l.prio >= 4
  AND (
    l.process_match = 1
    OR l.component_match = 1
    OR l.intent_match = 1
    OR l.error_match = 1
    OR (
      l.ts <= aw.anr_ts
      AND l.global_signal_match = 1
    )
  )
ORDER BY root_cause_eligible DESC, ABS(l.ts - aw.anr_ts), l.ts
LIMIT 40
