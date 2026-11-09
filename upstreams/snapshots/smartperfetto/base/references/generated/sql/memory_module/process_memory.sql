-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/memory_module.skill.yaml
-- Source SHA-256: f00717aba46f44cda52a71b3aac619d9a3dabf1eea6b54e5757a38a480c000bc

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
