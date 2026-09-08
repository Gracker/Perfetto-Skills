-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 59c8f596d0111ef62440eb05318e85cfc2368d1d0b62d50ed6b1147b21e58aac
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM process
      WHERE name = 'surfaceflinger'
         OR name = '/system/bin/surfaceflinger'
    ) THEN 1
    ELSE 0
  END as has_sf_process,
  COALESCE(
    (SELECT upid FROM process
     WHERE name = 'surfaceflinger' OR name = '/system/bin/surfaceflinger'
     LIMIT 1),
    0
  ) as sf_upid,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM slice s
      JOIN thread_track tt ON s.track_id = tt.id
      JOIN thread t ON tt.utid = t.utid
      JOIN process p ON t.upid = p.upid
      WHERE (p.name = 'surfaceflinger' OR p.name = '/system/bin/surfaceflinger')
        AND (s.name GLOB '*onMessageInvalidate*'
             OR s.name GLOB '*onMessageRefresh*'
             OR s.name GLOB '*composite*'
             OR s.name GLOB '*Composite*')
      LIMIT 1
    ) THEN 1
    ELSE 0
  END as has_composition_data
