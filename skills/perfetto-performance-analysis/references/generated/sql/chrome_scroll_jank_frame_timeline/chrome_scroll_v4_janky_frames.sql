-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/chrome_scroll_jank_frame_timeline.skill.yaml
-- Source SHA-256: 2aa88e4f3cc40101c7a97eefeb3cfa517026c5c827e22d0cd8894af2a57da2a4
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  results.id AS frame_id,
  info.scroll_id,
  printf('%d', results.ts) AS ts,
  ROUND(results.dur / 1e6, 2) AS dur_ms,
  results.vsyncs_since_previous_frame,
  results.first_scroll_update_type,
  results.damage_type,
  ROUND(results.real_abs_total_raw_delta_pixels, 2) AS real_abs_total_raw_delta_pixels,
  GROUP_CONCAT(DISTINCT tags.tag) AS jank_tags
FROM chrome_scroll_jank_v4_results AS results
LEFT JOIN chrome_scroll_frame_info_v4 AS info
  ON info.id = results.id
LEFT JOIN chrome_scroll_jank_tags_v4 AS tags
  ON tags.frame_id = results.id
WHERE results.is_janky
  AND (${start_ts} IS NULL OR results.ts + results.dur > ${start_ts})
  AND (${end_ts} IS NULL OR results.ts < ${end_ts})
GROUP BY results.id
ORDER BY results.vsyncs_since_previous_frame DESC, results.ts
LIMIT 100
