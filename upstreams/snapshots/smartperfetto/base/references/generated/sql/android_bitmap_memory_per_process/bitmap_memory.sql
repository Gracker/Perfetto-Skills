-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: 1b5b8388a9a3b0ee3fbe651cab6e8b3ccd6b2258a0c3313e7633833fb896f08c
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

SELECT
  process_name,
  bitmap_count,
  bitmap_memory AS total_bytes
FROM android_bitmap_counters_per_process
WHERE (
  ('${process_name}' = '' AND '${package}' = '')
  OR process_name GLOB '${process_name}*'
  OR ('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*')
)
ORDER BY bitmap_memory DESC
LIMIT 30
