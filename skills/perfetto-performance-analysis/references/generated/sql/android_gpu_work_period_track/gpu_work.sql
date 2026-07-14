-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_gpu_work_period_track.skill.yaml
-- Source SHA-256: 8a497f4a41658ca2975e94bec53ccda4461bdd56763195ae3a57f32807c97017
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

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
