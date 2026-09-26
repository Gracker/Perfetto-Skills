-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: b4477788d50246d11d2483cd0837b27f8088afd90565197ab4f32613a52e680d
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  oom_score_adj,
  COUNT(*) as kill_count,
  GROUP_CONCAT(DISTINCT process_name) as killed_processes
FROM android_lmk_events
WHERE ts >= ${anr_ctx.data[0].anr_ts} - ${anr_ctx.data[0].timeout_ns}
  AND ts <= ${anr_ctx.data[0].anr_ts}
GROUP BY oom_score_adj
ORDER BY kill_count DESC
