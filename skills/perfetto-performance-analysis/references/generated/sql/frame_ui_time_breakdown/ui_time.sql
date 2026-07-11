-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/frame_ui_time_breakdown.skill.yaml
-- Source SHA-256: e954401abb0cdd3049a98ff540b0dcb21f44e7008292d852ac5fdc4426d59fcd
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  frame_id,
  ROUND(ui_time / 1e6, 2) AS ui_time_ms
FROM android_frames_ui_time
ORDER BY ui_time DESC
LIMIT 100
