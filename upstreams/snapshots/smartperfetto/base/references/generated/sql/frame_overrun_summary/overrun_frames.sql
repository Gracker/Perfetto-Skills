-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/frame_overrun_summary.skill.yaml
-- Source SHA-256: 2ef5423c5d7600d720f049fe458bccf4b167e2319a423fa99c754d3b4e6de88f
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  frame_id,
  ts,
  ROUND(dur / 1e6, 2) AS dur_ms,
  ROUND(overrun / 1e6, 2) AS overrun_ms
FROM android_frames_overrun
ORDER BY overrun DESC
LIMIT 100
