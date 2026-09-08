-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: fcb998f355d4b59effa774ad1bbdf5e5f786de7a6b686385a57f6cfea779555f
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH bitmap_rows AS (
  SELECT
    COALESCE(receiver.name, printf('upid:%d', b.upid)) AS receiver_process,
    COALESCE(b.source_process_name, printf('pid:%d', b.source_pid), 'unknown') AS source_process,
    b.*
  FROM heap_graph_bitmaps b
  LEFT JOIN process receiver ON receiver.upid = b.upid
  WHERE b.source_id IS NOT NULL
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
