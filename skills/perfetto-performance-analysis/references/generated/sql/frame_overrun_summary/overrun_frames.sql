-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/frame_overrun_summary.skill.yaml
-- Source SHA-256: 8d3f12c4ef5cd70e43445492df11219fc663818ce30eee71c44713c49ddec600
-- Source commit: 42ef4dd2878646bf238a54d53c934d4d4f3e4b3f

SELECT
  o.frame_id,
  MIN(a.ts) AS ts,
  ROUND(MAX(a.dur) / 1e6, 2) AS dur_ms,
  ROUND(o.overrun / 1e6, 2) AS overrun_ms
FROM android_frames_overrun o
LEFT JOIN actual_frame_timeline_slice a
  ON CAST(a.name AS INTEGER) = o.frame_id
GROUP BY o.frame_id, o.overrun
ORDER BY o.overrun DESC
LIMIT 100
