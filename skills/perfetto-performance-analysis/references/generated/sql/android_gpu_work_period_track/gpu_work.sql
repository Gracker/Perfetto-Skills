-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_gpu_work_period_track.skill.yaml
-- Source SHA-256: 1ca33ba4563f2acd3f76a752f728eaa1b22e66bd299430dddfbe5960379dd9ff
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  ts,
  ROUND(dur / 1e6, 2) AS dur_ms,
  uid
FROM android_gpu_work_period_track
ORDER BY ts ASC
LIMIT 100
