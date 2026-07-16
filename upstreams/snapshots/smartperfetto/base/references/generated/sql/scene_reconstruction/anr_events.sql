-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

-- ts in android_anrs is the detection moment (when timeout expired).
-- The actual blocking period is [ts - timeout, ts].
-- Use anr_dur_ms → default_anr_dur_ms fallback for the blocking window.
SELECT
  printf('%d', ts - CAST(COALESCE(anr_dur_ms, default_anr_dur_ms, 5000) AS INTEGER) * 1000000) AS ts,
  printf('%d', CAST(COALESCE(anr_dur_ms, default_anr_dur_ms, 5000) AS INTEGER) * 1000000) AS dur,
  'ANR: ' || REPLACE(REPLACE(process_name, 'com.', ''), 'android.', '') ||
    ' (' || COALESCE(anr_type, 'unknown') || ')' AS event,
  process_name,
  COALESCE(anr_type, 'unknown') AS anr_type,
  'anr' AS category
FROM android_anrs
ORDER BY ts
LIMIT 50
