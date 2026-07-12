-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: 3c84f44d6c902b27eaae06e9700024c9d6954005525a587cdbf9f2863e52423b
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH bitmap_rows AS (
  SELECT
    COALESCE(p.name, printf('upid:%d', b.upid)) AS process_name,
    b.*
  FROM heap_graph_bitmaps b
  LEFT JOIN process p ON p.upid = b.upid
  WHERE (
    ('${process_name}' = '' AND '${package}' = '')
    OR p.name GLOB '${process_name}*'
    OR p.name GLOB '${package}*'
  )
)
SELECT
  process_name,
  COUNT(*) AS bitmap_object_count,
  SUM(CASE WHEN reachable THEN 1 ELSE 0 END) AS reachable_count,
  SUM(COALESCE(native_size, 0) + COALESCE(self_size, 0)) AS total_bytes,
  SUM(COALESCE(native_size, 0)) AS native_bytes,
  SUM(COALESCE(self_size, 0)) AS java_self_bytes,
  SUM(CASE WHEN width IS NOT NULL AND height IS NOT NULL THEN 1 ELSE 0 END) AS known_dimension_count,
  MAX(width) AS max_width,
  MAX(height) AS max_height,
  GROUP_CONCAT(DISTINCT COALESCE(bitmap_storage_type, 'unknown')) AS storage_types
FROM bitmap_rows
GROUP BY process_name
ORDER BY total_bytes DESC
LIMIT 30
