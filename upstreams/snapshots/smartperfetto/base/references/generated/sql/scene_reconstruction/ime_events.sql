-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 59b4122937e29b04987a3c415c69cc1ce8120d970dcdd14b005ed5a34adbc22e

SELECT scene_rows.*, COUNT(*) OVER () AS total_rows FROM (
SELECT
  printf('%d', s.ts) AS ts,
  printf('%d', s.dur) AS dur,
  CASE
    WHEN s.name GLOB '*showSoftInput*'
      OR s.name GLOB '*InputMethodService*show*'
      OR s.name GLOB '*InputMethodManager*show*'
      THEN '键盘弹出 [' || CAST(s.dur / 1000000 AS INT) || 'ms]'
    WHEN s.name GLOB '*hideSoftInput*'
      OR s.name GLOB '*InputMethodService*hide*'
      OR s.name GLOB '*InputMethodManager*hide*'
      THEN '键盘收起 [' || CAST(s.dur / 1000000 AS INT) || 'ms]'
    ELSE NULL
  END AS event,
  CASE
    WHEN s.name GLOB '*show*' THEN 'ime_show'
    ELSE 'ime_hide'
  END AS ime_action,
  'ime' AS category
FROM slice s
WHERE s.dur > 5000000
  AND (
    s.name GLOB '*showSoftInput*'
    OR s.name GLOB '*hideSoftInput*'
    OR s.name GLOB '*InputMethodService*show*'
    OR s.name GLOB '*InputMethodService*hide*'
    OR s.name GLOB '*InputMethodManager*show*'
    OR s.name GLOB '*InputMethodManager*hide*'
  )
ORDER BY s.ts
) AS scene_rows
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)
