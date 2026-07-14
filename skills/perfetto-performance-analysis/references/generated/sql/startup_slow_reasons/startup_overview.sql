-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_slow_reasons.skill.yaml
-- Source SHA-256: 9280e9531cabb0d33f372861fc25136e7e273f9b5c0a3e1cb38d346213d38a58
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH startup_type_signals AS (
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
    AND sl.ts + sl.dur > st.ts AND sl.ts < st.ts + st.dur
    AND (sl.name = 'bindApplication'
         OR sl.name GLOB 'performCreate:*'
         OR sl.name GLOB 'handleRelaunchActivity*'
         OR sl.name GLOB 'relaunchActivity*')
  GROUP BY st.startup_id
),
process_age AS (
  SELECT
    s.startup_id,
    MAX(CASE
      WHEN p.start_ts IS NOT NULL
        AND p.start_ts >= s.ts - 5000000000
        AND p.start_ts <= s.ts + s.dur
      THEN 1 ELSE 0
    END) as process_created_during_startup
  FROM android_startups s
  LEFT JOIN android_startup_processes asp ON asp.startup_id = s.startup_id
  LEFT JOIN process p ON p.upid = asp.upid
  GROUP BY s.startup_id
),
startup_process AS (
  SELECT startup_id, MAX(upid) as upid
  FROM android_startup_processes
  GROUP BY startup_id
),
validated AS (
  SELECT
    s.startup_id,
    s.package,
    s.ts,
    CASE
      WHEN COALESCE(sts.has_bind_app, 0) = 1 THEN 'cold'
      WHEN COALESCE(sts.has_perform_create, 0) = 1 AND COALESCE(sts.has_bind_app, 0) = 0 THEN 'warm'
      WHEN COALESCE(sts.has_relaunch, 0) = 1 THEN 'warm'
      WHEN COALESCE(pa.process_created_during_startup, 0) = 1 THEN 'cold'
      ELSE s.startup_type
    END as startup_type,
    s.dur,
    ttd.time_to_initial_display,
    ttd.time_to_full_display,
    COALESCE(sp.upid, (
      SELECT p2.upid
      FROM process p2
      WHERE p2.name GLOB s.package || '*'
      ORDER BY p2.start_ts DESC
      LIMIT 1
    )) as upid
  FROM android_startups s
  LEFT JOIN startup_process sp ON sp.startup_id = s.startup_id
  LEFT JOIN android_startup_time_to_display ttd USING (startup_id)
  LEFT JOIN startup_type_signals sts USING (startup_id)
  LEFT JOIN process_age pa USING (startup_id)
)
SELECT
  startup_id,
  package,
  startup_type,
  ts,
  dur,
  upid,
  ROUND(dur / 1e6, 1) as dur_ms,
  ROUND(time_to_initial_display / 1e6, 1) as ttid_ms,
  ROUND(time_to_full_display / 1e6, 1) as ttfd_ms
FROM validated
ORDER BY dur DESC
