-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/memory_rss_high_watermark.skill.yaml
-- Source SHA-256: 37166099200b6eb3dfaa4d62fc6e08bb63e5baa6671f7d1a9dc8530a3a6a36b9
-- Source commit: 42ef4dd2878646bf238a54d53c934d4d4f3e4b3f

SELECT
  process_name,
  ROUND(rss_high_watermark / 1024.0, 2) AS rss_high_watermark_kb
FROM memory_rss_high_watermark_per_process
WHERE ('${process_name}' = '' OR process_name = '${process_name}' OR process_name GLOB '${process_name}:*')
ORDER BY rss_high_watermark DESC
LIMIT ${top_n|30}
