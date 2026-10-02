-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 73174387dbcbe50ec6a308be4a914c35d9587942dec32311fae979b1974a8d4f

SELECT
  oom_score_adj,
  COUNT(*) as kill_count,
  GROUP_CONCAT(DISTINCT process_name) as killed_processes
FROM android_lmk_events
WHERE ts >= ${anr_ctx.data[0].anr_ts} - ${anr_ctx.data[0].timeout_ns}
  AND ts <= ${anr_ctx.data[0].anr_ts}
GROUP BY oom_score_adj
ORDER BY kill_count DESC
