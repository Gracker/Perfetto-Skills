-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

-- Pair DOWN → nearest UP per key_code using ROW_NUMBER for strict matching.
-- Handles repeats/double-taps by assigning each DOWN its own ordinal.
WITH downs AS (
  SELECT
    ts, key_code,
    ROW_NUMBER() OVER (PARTITION BY key_code ORDER BY ts) AS rn
  FROM android_key_events
  WHERE action = 0 AND key_code IN (3, 4, 187)
),
ups AS (
  SELECT
    ts AS up_ts, key_code,
    ROW_NUMBER() OVER (PARTITION BY key_code ORDER BY ts) AS rn
  FROM android_key_events
  WHERE action = 1 AND key_code IN (3, 4, 187)
)
SELECT
  printf('%d', d.ts) AS ts,
  printf('%d', COALESCE(u.up_ts - d.ts, 0)) AS dur,
  CASE d.key_code
    WHEN 4 THEN '返回键'
    WHEN 3 THEN 'Home键'
    WHEN 187 THEN '最近任务键'
  END AS event,
  CASE d.key_code
    WHEN 4 THEN 'back_key'
    WHEN 3 THEN 'home_key'
    WHEN 187 THEN 'recents_key'
  END AS key_name,
  'navigation_key' AS category
FROM downs d
LEFT JOIN ups u ON u.key_code = d.key_code AND u.rn = d.rn AND u.up_ts >= d.ts
WHERE COALESCE(u.up_ts - d.ts, 0) >= 0
ORDER BY d.ts
LIMIT 100
