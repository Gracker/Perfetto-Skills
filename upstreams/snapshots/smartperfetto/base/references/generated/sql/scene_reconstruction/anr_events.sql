-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 8832b9e9b6f0bb86a0676bcd50f367546a3406ef8111be90fe60511d26678d5b
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT scene_rows.*, COUNT(*) OVER () AS total_rows FROM (
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
) AS scene_rows
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)
