-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/sf_composition_in_range.skill.yaml
-- Source SHA-256: d3a3ab37e6a618fdebe97162b06b53a9f787a43fbeccbf22790bc04e73d8306d
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH sf_slices AS (
  SELECT
    s.name,
    s.dur,
    CASE
      WHEN s.name GLOB '*onMessageInvalidate*' THEN 'Invalidate'
      WHEN s.name GLOB '*onMessageRefresh*' THEN 'Refresh'
      WHEN s.name GLOB '*composite*' OR s.name GLOB '*Composite*' THEN 'Composite'
      WHEN s.name GLOB '*latchBuffer*' OR s.name GLOB '*Latch*' THEN 'Latch Buffer'
      WHEN s.name GLOB '*updateTexImage*' THEN 'Update Texture'
      WHEN s.name GLOB '*postComposition*' THEN 'Post Composition'
      WHEN s.name GLOB '*present*' OR s.name GLOB '*Present*' THEN 'Present'
      WHEN s.name GLOB '*commit*' OR s.name GLOB '*Commit*' THEN 'Commit'
      ELSE NULL
    END as composition_type
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = 'surfaceflinger' OR p.name = '/system/bin/surfaceflinger')
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts}) AND (${end_ts} IS NULL OR s.ts < ${end_ts})
    AND s.dur > 10000  -- > 10us
)
SELECT
  composition_type,
  COUNT(*) as count,
  ROUND(SUM(dur) / 1e6, 2) as total_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_ms
FROM sf_slices
WHERE composition_type IS NOT NULL
GROUP BY composition_type
HAVING total_ms > 0.05
ORDER BY composition_type
