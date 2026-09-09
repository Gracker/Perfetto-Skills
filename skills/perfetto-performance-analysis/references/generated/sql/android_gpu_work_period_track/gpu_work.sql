-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_gpu_work_period_track.skill.yaml
-- Source SHA-256: dad0f300552c8a78618be018d8930c345109988d414c37fcef819ee4752758f5
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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
        AND ('${package}' = '' OR p.package_name = '${package}' OR p.package_name GLOB '${package}:*')
    )
  )
ORDER BY s.ts ASC
LIMIT 100
