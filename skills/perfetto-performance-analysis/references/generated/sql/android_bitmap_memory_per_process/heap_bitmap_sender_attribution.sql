-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: 1b5b8388a9a3b0ee3fbe651cab6e8b3ccd6b2258a0c3313e7633833fb896f08c
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

WITH bitmap_rows AS (
  SELECT
    COALESCE(receiver.name, printf('upid:%d', b.upid)) AS receiver_process,
    COALESCE(b.source_process_name, printf('pid:%d', b.source_pid), 'unknown') AS source_process,
    b.*
  FROM heap_graph_bitmaps b
  LEFT JOIN process receiver ON receiver.upid = b.upid
  WHERE b.source_id IS NOT NULL
    AND COALESCE(b.self_size, 0) >= 0
    AND (
      ('${process_name}' = '' AND '${package}' = '')
      OR receiver.name GLOB '${process_name}*'
      OR ('${package}' = '' OR receiver.name = '${package}' OR receiver.name GLOB '${package}:*')
    )
)
SELECT
  receiver_process,
  source_process,
  COUNT(*) AS bitmap_count,
  SUM(COALESCE(native_size, 0) + COALESCE(self_size, 0)) AS total_bytes,
  GROUP_CONCAT(DISTINCT COALESCE(bitmap_storage_type, 'unknown')) AS receiver_storage_types,
  GROUP_CONCAT(DISTINCT COALESCE(source_storage_type, 'unknown')) AS source_storage_types
FROM bitmap_rows
GROUP BY receiver_process, source_process
ORDER BY total_bytes DESC, bitmap_count DESC
LIMIT 50
