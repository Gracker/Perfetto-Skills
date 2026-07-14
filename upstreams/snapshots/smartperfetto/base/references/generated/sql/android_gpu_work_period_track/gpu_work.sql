-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_gpu_work_period_track.skill.yaml
-- Source SHA-256: 8a497f4a41658ca2975e94bec53ccda4461bdd56763195ae3a57f32807c97017
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  s.ts,
  ROUND(s.dur / 1e6, 2) AS dur_ms,
  t.uid,
  t.gpu_id
FROM android_gpu_work_period_track t
JOIN slice s ON s.track_id = t.id
WHERE s.dur > 0
ORDER BY s.ts ASC
LIMIT 100
