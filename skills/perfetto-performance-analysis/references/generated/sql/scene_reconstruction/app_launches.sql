-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH RECURSIVE startup_check AS (
  SELECT 1 AS dummy WHERE EXISTS (
    SELECT 1 FROM sqlite_master WHERE type='table' AND name='android_startups'
  )
),
-- Reclassify startup_type: platform may report 'warm' even when
-- bindApplication exists (process killed + ActivityRecord survives).
-- bindApplication on main thread = cold start, period.
validated_startups AS (
  SELECT
    s.*,
    CASE
      WHEN EXISTS (
        SELECT 1 FROM android_startup_threads st
        JOIN thread_track tt ON tt.utid = st.utid
        JOIN slice sl ON sl.track_id = tt.id
        WHERE st.startup_id = s.startup_id
          AND st.is_main_thread = 1
          AND sl.name = 'bindApplication'
          AND sl.ts + sl.dur > st.ts AND sl.ts < st.ts + st.dur
      ) THEN 'cold'
      ELSE s.startup_type
    END AS validated_type
  FROM android_startups s
  WHERE s.dur > 0
)
SELECT
  s.startup_id,
  printf('%d', s.ts) AS ts,
  printf('%d', s.dur) AS dur,
  CASE s.validated_type
    WHEN 'cold' THEN '冷启动'
    WHEN 'warm' THEN '温启动'
    WHEN 'hot' THEN '热启动'
    ELSE '启动'
  END || ' ' ||
  REPLACE(REPLACE(s.package, 'com.', ''), 'android.', '') ||
  ' [' || CAST(s.dur / 1000000 AS INT) || 'ms]' AS event,
  s.validated_type AS startup_type,
  s.package,
  NULL AS ttid_ms,
  NULL AS ttfd_ms,
  'app_launch' AS category
FROM validated_startups s
ORDER BY s.ts
LIMIT 50
