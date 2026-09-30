-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 5b3df6636aa845fd7e5a72bd067025fd3ae618c026113c370b10c97284bdf3b2

SELECT
  oom_score_adj,
  COUNT(*) as kill_count,
  GROUP_CONCAT(DISTINCT process_name) as killed_processes
FROM android_lmk_events
WHERE ts >= ${anr_ctx.data[0].anr_ts} - ${anr_ctx.data[0].timeout_ns}
  AND ts <= ${anr_ctx.data[0].anr_ts}
GROUP BY oom_score_adj
ORDER BY kill_count DESC
