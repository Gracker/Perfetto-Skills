-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 883c9e637f8166269939f7f817af9ef900c89e2215ca90cb3c0ad0d45443daad
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH
sf_slices AS (
  SELECT
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
    END as phase
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = 'surfaceflinger' OR p.name = '/system/bin/surfaceflinger')
    AND s.dur > 10000  -- > 10us
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
),
total AS (
  SELECT SUM(dur) as total_dur FROM sf_slices WHERE phase IS NOT NULL
)
SELECT
  phase,
  COUNT(*) as count,
  SUM(dur) as total_dur,
  CAST(ROUND(AVG(dur)) AS INTEGER) as avg_dur,
  MAX(dur) as max_dur,
  ROUND(100.0 * SUM(dur) / NULLIF((SELECT total_dur FROM total), 0), 1) as time_pct
FROM sf_slices
WHERE phase IS NOT NULL
GROUP BY phase
ORDER BY total_dur DESC
