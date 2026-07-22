-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_gpu_work_period_track.skill.yaml
-- Source SHA-256: 89ee7d1b0cea4d3a9b04eca1c6861f1df717154d04473c1e5f3634676c910bab
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  s.ts,
  ROUND(s.dur / 1e6, 2) AS dur_ms,
  t.uid,
  t.gpu_id
FROM android_gpu_work_period_track t
JOIN slice s ON s.track_id = t.id
WHERE s.dur > 0
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  AND (
    '${package}' = ''
    OR EXISTS (
      SELECT 1
      FROM package_list p
      WHERE p.uid = t.uid
        AND p.package_name GLOB '${package}*'
    )
  )
ORDER BY s.ts ASC
LIMIT 100
