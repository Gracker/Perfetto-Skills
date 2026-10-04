-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 59b4122937e29b04987a3c415c69cc1ce8120d970dcdd14b005ed5a34adbc22e

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
