-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/chrome_scroll_jank_frame_timeline.skill.yaml
-- Source SHA-256: 2aa88e4f3cc40101c7a97eefeb3cfa517026c5c827e22d0cd8894af2a57da2a4
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  stats.scroll_id,
  printf('%d', scroll.ts) AS ts,
  ROUND(scroll.dur / 1e6, 2) AS dur_ms,
  stats.frame_count,
  stats.presented_frame_count,
  stats.janky_frame_count,
  stats.missed_vsyncs,
  ROUND(stats.janky_frame_percent, 2) AS janky_frame_percent
FROM chrome_scroll_stats AS stats
JOIN chrome_scrolls AS scroll
  ON scroll.id = stats.scroll_id
WHERE stats.janky_frame_count >= COALESCE(${min_janky_frames|1}, 1)
  AND (${start_ts} IS NULL OR scroll.ts + scroll.dur > ${start_ts})
  AND (${end_ts} IS NULL OR scroll.ts < ${end_ts})
ORDER BY stats.janky_frame_percent DESC, stats.janky_frame_count DESC
LIMIT 50
