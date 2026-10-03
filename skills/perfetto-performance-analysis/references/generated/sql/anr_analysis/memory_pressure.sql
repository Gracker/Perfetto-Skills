-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 886c11c88b8de59f7a759bb5510cc207277be4fee7d37149ed00f9c1c29c96f9

SELECT
  oom_score_adj,
  COUNT(*) as kill_count,
  GROUP_CONCAT(DISTINCT process_name) as killed_processes
FROM android_lmk_events
WHERE ts >= ${anr_ctx.data[0].anr_ts} - ${anr_ctx.data[0].timeout_ns}
  AND ts <= ${anr_ctx.data[0].anr_ts}
GROUP BY oom_score_adj
ORDER BY kill_count DESC
