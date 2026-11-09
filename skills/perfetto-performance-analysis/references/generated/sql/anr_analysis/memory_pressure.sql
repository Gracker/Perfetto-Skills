-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: f5a02f9bd8e59acab9537e22bc5ddcc6db2828930cd8fab0d630eb4ae1e079a2

SELECT
  oom_score_adj,
  COUNT(*) as kill_count,
  GROUP_CONCAT(DISTINCT process_name) as killed_processes
FROM android_lmk_events
WHERE ts >= ${anr_ctx.data[0].anr_ts} - ${anr_ctx.data[0].timeout_ns}
  AND ts <= ${anr_ctx.data[0].anr_ts}
GROUP BY oom_score_adj
ORDER BY kill_count DESC
