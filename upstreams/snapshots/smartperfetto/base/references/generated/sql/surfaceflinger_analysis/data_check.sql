-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 883c9e637f8166269939f7f817af9ef900c89e2215ca90cb3c0ad0d45443daad
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

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
