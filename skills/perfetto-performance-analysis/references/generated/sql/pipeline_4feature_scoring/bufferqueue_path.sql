-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/pipeline_4feature_scoring.skill.yaml
-- Source SHA-256: 510fbb63523a223a8d40f61f49a3090fc0b9dcc00bebf3a319e94aaf6506408a
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH
blast AS (
  SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*BLASTBufferQueue*'
),
apply_tx AS (
  SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*applyTransaction*'
),
qb AS (
  SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*queueBuffer*'
),
lock_canvas AS (
  SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*lockCanvas*' OR name GLOB '*unlockCanvasAndPost*'
),
asurface_tx AS (
  SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*ASurfaceTransaction*'
),
update_tex AS (
  SELECT COUNT(*) as cnt FROM slice WHERE name GLOB '*updateTexImage*'
)
SELECT
  CASE
    WHEN (SELECT cnt FROM blast) > 0 AND (SELECT cnt FROM apply_tx) > 0 THEN 'BBQ_TRANSACTION_INPROC (BLAST)'
    WHEN (SELECT cnt FROM asurface_tx) > 0 AND (SELECT cnt FROM blast) = 0 THEN 'SURFACECONTROL_TRANSACTION_DIRECT (NDK)'
    WHEN (SELECT cnt FROM update_tex) > 0 THEN 'HOST_RESAMPLE (TextureView)'
    WHEN (SELECT cnt FROM lock_canvas) > 0 AND (SELECT cnt FROM blast) = 0 THEN 'ACQUIRE_FENCE_NONE_INPROC (Software)'
    WHEN (SELECT cnt FROM qb) > 0 AND (SELECT cnt FROM blast) = 0 AND (SELECT cnt FROM apply_tx) = 0 THEN 'BUFFERQUEUE_INPROC (Legacy)'
    ELSE 'UNKNOWN'
  END as bq_path_type,
  (SELECT cnt FROM blast) as blast_count,
  (SELECT cnt FROM qb) - (SELECT cnt FROM blast) as legacy_count,
  (SELECT cnt FROM lock_canvas) as software_count,
  (SELECT cnt FROM asurface_tx) as ndk_sc_count
