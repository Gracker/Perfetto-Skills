-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/startup_analysis.skill.yaml
-- Source SHA-256: 96b682a4206afafddcfb6e63c60e842921381a674744f413881a609e862ef41b
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  'MainThread Hot Slice' as item,
  'main_thread_slices.percent_of_startup' as primary_metric,
  ROUND(COALESCE(${main_thread_slices.data[0].percent_of_startup}, 0), 2) as primary_value,
  '>20% OR max_dur_ms>100' as primary_threshold,
  'main_thread_slices.max_dur_ms' as corroborating_metric,
  ROUND(COALESCE(${main_thread_slices.data[0].max_dur_ms}, 0), 2) as corroborating_value,
  '>100ms' as corroborating_threshold,
  CASE
    WHEN (COALESCE(${main_thread_slices.data[0].percent_of_startup}, 0) > 20 OR COALESCE(${main_thread_slices.data[0].max_dur_ms}, 0) > 100)
         AND COALESCE(${main_thread_slices.data[0].max_dur_ms}, 0) > 100 THEN 'confirmed'
    WHEN (COALESCE(${main_thread_slices.data[0].percent_of_startup}, 0) > 20 OR COALESCE(${main_thread_slices.data[0].max_dur_ms}, 0) > 100) THEN 'needs_corroboration'
    ELSE 'normal'
  END as status
UNION ALL
SELECT
  'MainThread File IO' as item,
  'main_thread_file_io.percent_of_startup' as primary_metric,
  ROUND(COALESCE(${main_thread_file_io.data[0].percent_of_startup}, 0), 2) as primary_value,
  '>5%' as primary_threshold,
  'main_thread_file_io.total_dur_ms' as corroborating_metric,
  ROUND(COALESCE(${main_thread_file_io.data[0].total_dur_ms}, 0), 2) as corroborating_value,
  '>50ms' as corroborating_threshold,
  CASE
    WHEN COALESCE(${main_thread_file_io.data[0].percent_of_startup}, 0) > 5
         AND COALESCE(${main_thread_file_io.data[0].total_dur_ms}, 0) > 50 THEN 'confirmed'
    WHEN COALESCE(${main_thread_file_io.data[0].percent_of_startup}, 0) > 5 THEN 'needs_corroboration'
    ELSE 'normal'
  END as status
UNION ALL
SELECT
  'Binder Total' as item,
  'startup_binder.percent_of_startup' as primary_metric,
  ROUND(COALESCE(${startup_binder.data[0].percent_of_startup}, 0), 2) as primary_value,
  '>20%' as primary_threshold,
  'main_sync_binder.percent_of_startup' as corroborating_metric,
  ROUND(COALESCE(${main_sync_binder.data[0].percent_of_startup}, 0), 2) as corroborating_value,
  '>5%' as corroborating_threshold,
  CASE
    WHEN COALESCE(${startup_binder.data[0].percent_of_startup}, 0) > 20
         AND COALESCE(${main_sync_binder.data[0].percent_of_startup}, 0) > 5 THEN 'confirmed'
    WHEN COALESCE(${startup_binder.data[0].percent_of_startup}, 0) > 20 THEN 'needs_corroboration'
    ELSE 'normal'
  END as status
UNION ALL
SELECT
  'Main Sync Binder' as item,
  'main_sync_binder.percent_of_startup' as primary_metric,
  ROUND(COALESCE(${main_sync_binder.data[0].percent_of_startup}, 0), 2) as primary_value,
  '>8%' as primary_threshold,
  'main_binder_blocking.dur_ms' as corroborating_metric,
  ROUND(COALESCE(${main_binder_blocking.data[0].dur_ms}, 0), 2) as corroborating_value,
  '>16ms' as corroborating_threshold,
  CASE
    WHEN COALESCE(${main_sync_binder.data[0].percent_of_startup}, 0) > 8
         AND COALESCE(${main_binder_blocking.data[0].dur_ms}, 0) > 16 THEN 'confirmed'
    WHEN COALESCE(${main_sync_binder.data[0].percent_of_startup}, 0) > 8 THEN 'needs_corroboration'
    ELSE 'normal'
  END as status
UNION ALL
SELECT
  'Sched Latency' as item,
  'sched_latency.severe_delays' as primary_metric,
  ROUND(COALESCE(${sched_latency.data[0].severe_delays}, 0), 2) as primary_value,
  '>3' as primary_threshold,
  'sched_latency.max_wait_ms' as corroborating_metric,
  ROUND(COALESCE(${sched_latency.data[0].max_wait_ms}, 0), 2) as corroborating_value,
  '>8ms' as corroborating_threshold,
  CASE
    WHEN COALESCE(${sched_latency.data[0].severe_delays}, 0) > 3
         AND COALESCE(${sched_latency.data[0].max_wait_ms}, 0) > 8 THEN 'confirmed'
    WHEN COALESCE(${sched_latency.data[0].severe_delays}, 0) > 3 THEN 'needs_corroboration'
    ELSE 'normal'
  END as status
