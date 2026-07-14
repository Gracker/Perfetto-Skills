-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/frame_ui_time_breakdown.skill.yaml
-- Source SHA-256: e954401abb0cdd3049a98ff540b0dcb21f44e7008292d852ac5fdc4426d59fcd
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  frame_id,
  ROUND(ui_time / 1e6, 2) AS ui_time_ms
FROM android_frames_ui_time
ORDER BY ui_time DESC
LIMIT 100
