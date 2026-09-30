-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: c4d29f5ee21c06081cc03ddeefcc79718e488db294e4623000e124ce9c292f0b

WITH process_mem AS (
  SELECT
    pt.name AS process_name,
    ct.name AS counter_name,
    CAST(AVG(c.value) / 1024 / 1024 AS INTEGER) AS avg_mb,
    CAST(MAX(c.value) / 1024 / 1024 AS INTEGER) AS max_mb
  FROM counter c
  JOIN process_counter_track ct ON c.track_id = ct.id
  JOIN process pt ON ct.upid = pt.upid
  WHERE ct.name LIKE '%mem%'
    OR ct.name LIKE '%rss%'
    OR ct.name LIKE '%RSS%'
    OR ct.name LIKE '%heap%'
  GROUP BY pt.name, ct.name
)
SELECT
  process_name,
  counter_name,
  avg_mb,
  max_mb
FROM process_mem
WHERE avg_mb > 1
ORDER BY max_mb DESC
LIMIT 30
