-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/pipeline_4feature_scoring.skill.yaml
-- Source SHA-256: 1e79317b0855a512d32bbad13dab94931b70017b7cf9f585ab505151c272ea3a
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

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
