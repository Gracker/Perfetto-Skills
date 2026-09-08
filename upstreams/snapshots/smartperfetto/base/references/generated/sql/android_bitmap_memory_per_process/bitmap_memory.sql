-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
-- Source SHA-256: fcb998f355d4b59effa774ad1bbdf5e5f786de7a6b686385a57f6cfea779555f
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
