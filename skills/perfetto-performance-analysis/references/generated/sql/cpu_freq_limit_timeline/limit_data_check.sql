-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_freq_limit_timeline.skill.yaml
-- Source SHA-256: 9ca20ae0bd75e18a790d8f725bc86549da9ef82647525a0180194ab11908877b
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM cpu_counter_track WHERE type = 'cpu_max_frequency_limit'
  ) THEN 1 ELSE 0 END AS has_max_limit_track,
  CASE WHEN EXISTS (
    SELECT 1 FROM cpu_counter_track WHERE type = 'cpu_min_frequency_limit'
  ) THEN 1 ELSE 0 END AS has_min_limit_track,
  (SELECT COUNT(*) FROM cpu_counter_track
    WHERE type IN ('cpu_max_frequency_limit', 'cpu_min_frequency_limit')) AS limit_track_count
