-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/memory_rss_high_watermark.skill.yaml
-- Source SHA-256: 75630a178e2ff5876a3926a7d57c8937b30fe0b6e6f00a37d41122c1611d689c
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  process_name,
  rss_high_watermark_kb
FROM memory_rss_high_watermark_per_process
WHERE (process_name GLOB '${process_name}*' OR '${process_name}' = '')
ORDER BY rss_high_watermark_kb DESC
LIMIT ${top_n|30}
