-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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
LIMIT 100
