-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: fcb998f355d4b59effa774ad1bbdf5e5f786de7a6b686385a57f6cfea779555f
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH bitmap_rows AS (
  SELECT
    COALESCE(p.name, printf('upid:%d', b.upid)) AS process_name,
    b.*
  FROM heap_graph_bitmaps b
  LEFT JOIN process p ON p.upid = b.upid
  WHERE (
    ('${process_name}' = '' AND '${package}' = '')
    OR p.name GLOB '${process_name}*'
    OR ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
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
