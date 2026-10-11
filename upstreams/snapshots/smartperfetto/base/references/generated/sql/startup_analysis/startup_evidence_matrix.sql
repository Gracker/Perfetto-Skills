-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/startup_analysis.skill.yaml
-- Source SHA-256: 8c1bf5a38d906e39a6f1d4430b5946930f50b15a3a389f49dcebb63d8e74b2bf

SELECT
  'MainThread Hot Slice' as item,
  'main_thread_slices.top.percent_of_startup' as primary_metric,
  ROUND(${main_thread_slices.data[0].percent_of_startup|NULL}, 2) as primary_value,
  '>20% OR max_dur_ms>100' as primary_threshold,
  'main_thread_slices.top.max_dur_ms' as corroborating_metric,
  ROUND(${main_thread_slices.data[0].max_dur_ms|NULL}, 2) as corroborating_value,
  '>100ms' as corroborating_threshold,
  CASE
    WHEN ${main_thread_slices.data[0].percent_of_startup|NULL} IS NULL THEN 'not_observed'
    WHEN (COALESCE(${main_thread_slices.data[0].percent_of_startup|NULL}, 0) > 20 OR COALESCE(${main_thread_slices.data[0].max_dur_ms|NULL}, 0) > 100)
         AND COALESCE(${main_thread_slices.data[0].max_dur_ms|NULL}, 0) > 100 THEN 'confirmed'
    WHEN (COALESCE(${main_thread_slices.data[0].percent_of_startup|NULL}, 0) > 20 OR COALESCE(${main_thread_slices.data[0].max_dur_ms|NULL}, 0) > 100) THEN 'needs_corroboration'
    ELSE 'normal'
  END as status
UNION ALL
SELECT
  'MainThread File IO' as item,
  'main_thread_file_io.all_percent_of_startup' as primary_metric,
  ROUND(${main_thread_file_io.data[0].all_percent_of_startup|NULL}, 2) as primary_value,
  '>5%' as primary_threshold,
  'main_thread_file_io.all_total_dur_ms' as corroborating_metric,
  ROUND(${main_thread_file_io.data[0].all_total_dur_ms|NULL}, 2) as corroborating_value,
  '>50ms' as corroborating_threshold,
  CASE
    WHEN ${main_thread_file_io.data[0].all_percent_of_startup|NULL} IS NULL THEN 'not_observed'
    WHEN COALESCE(${main_thread_file_io.data[0].all_percent_of_startup|NULL}, 0) > 5
         AND COALESCE(${main_thread_file_io.data[0].all_total_dur_ms|NULL}, 0) > 50 THEN 'confirmed'
    WHEN COALESCE(${main_thread_file_io.data[0].all_percent_of_startup|NULL}, 0) > 5 THEN 'needs_corroboration'
    ELSE 'normal'
  END as status
UNION ALL
SELECT
  'Binder Total' as item,
  'startup_binder.all_percent_of_startup' as primary_metric,
  ROUND(${startup_binder.data[0].all_percent_of_startup|NULL}, 2) as primary_value,
  '>20%' as primary_threshold,
  'main_sync_binder.all_percent_of_startup' as corroborating_metric,
  ROUND(${main_sync_binder.data[0].all_percent_of_startup|NULL}, 2) as corroborating_value,
  '>5%' as corroborating_threshold,
  CASE
    WHEN ${startup_binder.data[0].all_percent_of_startup|NULL} IS NULL THEN 'not_observed'
    WHEN COALESCE(${startup_binder.data[0].all_percent_of_startup|NULL}, 0) > 20
         AND COALESCE(${main_sync_binder.data[0].all_percent_of_startup|NULL}, 0) > 5 THEN 'confirmed'
    WHEN COALESCE(${startup_binder.data[0].all_percent_of_startup|NULL}, 0) > 20 THEN 'needs_corroboration'
    ELSE 'normal'
  END as status
UNION ALL
SELECT
  'Main Sync Binder' as item,
  'main_sync_binder.all_percent_of_startup' as primary_metric,
  ROUND(${main_sync_binder.data[0].all_percent_of_startup|NULL}, 2) as primary_value,
  '>8%' as primary_threshold,
  'main_binder_blocking.top.dur_ms' as corroborating_metric,
  ROUND(${main_binder_blocking.data[0].dur_ms|NULL}, 2) as corroborating_value,
  '>16ms' as corroborating_threshold,
  CASE
    WHEN ${main_sync_binder.data[0].all_percent_of_startup|NULL} IS NULL THEN 'not_observed'
    WHEN COALESCE(${main_sync_binder.data[0].all_percent_of_startup|NULL}, 0) > 8
         AND COALESCE(${main_binder_blocking.data[0].dur_ms|NULL}, 0) > 16 THEN 'confirmed'
    WHEN COALESCE(${main_sync_binder.data[0].all_percent_of_startup|NULL}, 0) > 8 THEN 'needs_corroboration'
    ELSE 'normal'
  END as status
UNION ALL
SELECT
  'Sched Latency' as item,
  'sched_latency.all_severe_delays' as primary_metric,
  ROUND(${sched_latency.data[0].all_severe_delays|NULL}, 2) as primary_value,
  '>3' as primary_threshold,
  'sched_latency.all_max_wait_ms' as corroborating_metric,
  ROUND(${sched_latency.data[0].all_max_wait_ms|NULL}, 2) as corroborating_value,
  '>8ms' as corroborating_threshold,
  CASE
    WHEN ${sched_latency.data[0].all_severe_delays|NULL} IS NULL THEN 'not_observed'
    WHEN COALESCE(${sched_latency.data[0].all_severe_delays|NULL}, 0) > 3
         AND COALESCE(${sched_latency.data[0].all_max_wait_ms|NULL}, 0) > 8 THEN 'confirmed'
    WHEN COALESCE(${sched_latency.data[0].all_severe_delays|NULL}, 0) > 3 THEN 'needs_corroboration'
    ELSE 'normal'
  END as status
