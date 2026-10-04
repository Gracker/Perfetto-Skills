-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 59b4122937e29b04987a3c415c69cc1ce8120d970dcdd14b005ed5a34adbc22e

SELECT scene_rows.*, COUNT(*) OVER () AS total_rows FROM (
-- A frame after UP does not prove fling. Confirmed fling evidence is
-- collected by the scene investigation, with producer and object identity.
SELECT printf('%d', ts) AS ts, '0' AS dur, '' AS event,
  0 AS frame_count, 0 AS jank_frames, NULL AS app_package,
  'inertial_scroll' AS category, 'unavailable' AS source_status
FROM slice WHERE 0
) AS scene_rows
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)
