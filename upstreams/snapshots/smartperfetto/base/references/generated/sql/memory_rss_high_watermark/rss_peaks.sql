-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/memory_rss_high_watermark.skill.yaml
-- Source SHA-256: 4cf80939e6b952de97407a954e1b420e4a2e52e02330c003a6cd1fa148a49cd7
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

SELECT
  process_name,
  ROUND(rss_high_watermark / 1024.0, 2) AS rss_high_watermark_kb
FROM memory_rss_high_watermark_per_process
WHERE (process_name GLOB '${process_name}*' OR '${process_name}' = '')
ORDER BY rss_high_watermark DESC
LIMIT ${top_n|30}
