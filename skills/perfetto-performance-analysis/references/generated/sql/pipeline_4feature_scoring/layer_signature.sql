-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/pipeline_4feature_scoring.skill.yaml
-- Source SHA-256: 1e79317b0855a512d32bbad13dab94931b70017b7cf9f585ab505151c272ea3a
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH
dominant_pkg AS (
  SELECT
    CASE
      WHEN '${package}' <> '' THEN '${package}'
      ELSE (
        SELECT CASE
                 WHEN instr(p.process_name, ':') > 0 THEN substr(p.process_name, 1, instr(p.process_name, ':') - 1)
                 ELSE p.process_name
               END
        FROM thread_slice p
        WHERE p.thread_name = 'RenderThread' AND p.name GLOB 'DrawFrame*'
        GROUP BY p.upid
        ORDER BY COUNT(*) DESC
        LIMIT 1
      )
    END as pkg
),
app_layers AS (
  SELECT DISTINCT layer_name
  FROM android_frames_layers
  WHERE layer_name IS NOT NULL
    AND layer_name GLOB '*' || (SELECT pkg FROM dominant_pkg) || '*'
)
SELECT
  COALESCE((SELECT COUNT(*) FROM app_layers), 0) as app_layer_count,
  CASE
    WHEN COALESCE((SELECT COUNT(*) FROM app_layers), 0) = 0 THEN 'no_layer_or_functor_path'
    WHEN COALESCE((SELECT COUNT(*) FROM app_layers), 0) = 1 THEN 'single_layer_baseline_or_textureview'
    WHEN COALESCE((SELECT COUNT(*) FROM app_layers), 0) = 2 THEN 'dual_layer_surfaceview_or_dialog'
    ELSE 'multi_layer_complex'
  END as layer_signature_type
