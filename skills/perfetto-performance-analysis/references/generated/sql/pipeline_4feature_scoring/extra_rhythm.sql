-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/pipeline_4feature_scoring.skill.yaml
-- Source SHA-256: 1e79317b0855a512d32bbad13dab94931b70017b7cf9f585ab505151c272ea3a
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH
swappy AS (SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*Swappy*' OR name GLOB '*SwappyVk_*'),
achoreographer AS (SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*AChoreographer*'),
set_frame_rate AS (SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*setFrameRate*' OR name GLOB '*setFrameRateCategory*'),
engine_loop AS (SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*PlayerLoop*' OR name GLOB '*FEngineLoop*' OR name GLOB '*MainLoop*'),
camera AS (SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*processCaptureRequest*' OR name GLOB '*processCaptureResult*'),
codec AS (SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*releaseOutputBuffer*')
SELECT
  CASE
    WHEN (SELECT cnt FROM swappy) > 0 THEN 'swappy_pacing'
    WHEN (SELECT cnt FROM achoreographer) > 0 THEN 'achoreographer'
    WHEN (SELECT cnt FROM engine_loop) > 0 THEN 'engine_main_loop'
    WHEN (SELECT cnt FROM camera) > 0 THEN 'camera_request_activity'
    WHEN (SELECT cnt FROM codec) > 0 THEN 'video_codec_pacing'
    WHEN (SELECT cnt FROM set_frame_rate) > 0 THEN 'set_frame_rate_voted'
    ELSE 'vsync_app_only'
  END as rhythm_source,
  CASE
    WHEN (SELECT cnt FROM swappy) = 0
         AND (SELECT cnt FROM achoreographer) = 0
         AND (SELECT cnt FROM engine_loop) = 0
         AND (SELECT cnt FROM camera) = 0
         AND (SELECT cnt FROM codec) = 0
    THEN 'yes' ELSE 'no'
  END as vsync_app_only
