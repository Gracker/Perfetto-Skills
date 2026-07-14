-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: 3c84f44d6c902b27eaae06e9700024c9d6954005525a587cdbf9f2863e52423b
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  process_name,
  bitmap_count,
  bitmap_memory AS total_bytes
FROM android_bitmap_counters_per_process
WHERE (
  ('${process_name}' = '' AND '${package}' = '')
  OR process_name GLOB '${process_name}*'
  OR process_name GLOB '${package}*'
)
ORDER BY bitmap_memory DESC
LIMIT 30
