-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 611a06dd906d52c4f70b68262fb7f661fe1ea8b92a26e8ebb2eac7714969c84a

WITH frames AS (
  SELECT
    upid,
    COALESCE(NULLIF(name, ''), CAST(surface_frame_token AS TEXT),
      CAST(display_frame_token AS TEXT), 'slice:' || id) AS frame_key,
    MAX(jank_type IS NOT NULL AND jank_type != 'None') AS jank_tagged
  FROM actual_frame_timeline_slice
  WHERE ts IS NOT NULL AND dur IS NOT NULL AND dur >= 0
  GROUP BY upid, frame_key
)
SELECT
  COUNT(*) AS total_frames,
  COALESCE(SUM(jank_tagged), 0) AS jank_frames,
  COUNT(DISTINCT upid) AS process_count,
  COALESCE(SUM(upid IS NULL), 0) AS unattributed_frames,
  'trace_wide_all_processes' AS evidence_scope,
  (SELECT start_ts FROM trace_bounds) AS trace_start_ts,
  (SELECT end_ts FROM trace_bounds) AS trace_end_ts,
  'observed' AS frame_population_evidence
FROM frames
