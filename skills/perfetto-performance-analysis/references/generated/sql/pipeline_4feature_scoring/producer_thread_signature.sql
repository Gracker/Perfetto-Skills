-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/pipeline_4feature_scoring.skill.yaml
-- Source SHA-256: 2188f6c3732115b4eac2d4d5250a23f8ff912ecab084d6aabc732df5c69ccef3
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH
dominant_process AS (
  SELECT upid, process_name
  FROM thread_slice
  WHERE process_name IS NOT NULL
    AND process_name NOT LIKE 'com.android.systemui%'
    AND process_name NOT LIKE 'system_server%'
    AND name IS NOT NULL
    AND (
      (thread_name = 'RenderThread' AND name GLOB 'DrawFrame*')
      OR (name GLOB '*Choreographer#doFrame*')
      OR (name GLOB '*eglSwapBuffers*')
      OR (name GLOB '*vkQueuePresentKHR*')
    )
  GROUP BY upid
  HAVING COUNT(*) > 5
  ORDER BY COUNT(*) DESC
  LIMIT 1
),
producer_threads AS (
  SELECT t.name as thread_name
  FROM thread t
  WHERE t.upid IN (SELECT upid FROM dominant_process)
    AND t.name IS NOT NULL
    AND (
      t.name = 'RenderThread'
      OR t.name = 'main'
      OR t.name = '1.ui'
      OR t.name = '1.raster'
      OR t.name = '1.io'
      OR t.name GLOB 'GLThread*'
      OR t.name GLOB 'CrRendererMain*'
      OR t.name GLOB 'VizCompositorThread*'
      OR t.name = 'Compositor'
      OR t.name GLOB 'CompositorTileWorker*'
      OR t.name GLOB 'UnityMain*'
      OR t.name GLOB 'UnityGfx*'
      OR t.name = 'GameThread'
      OR t.name = 'RHIThread'
      OR t.name = 'RenderThread'
      OR t.name GLOB 'GodotMain*'
      OR t.name GLOB 'mqt_js*'
      OR t.name GLOB 'mqt_native*'
      OR t.name GLOB '*Vulkan*'
      OR t.name GLOB 'VkQueue*'
    )
)
SELECT
  COALESCE((SELECT COUNT(*) FROM producer_threads), 0) as producer_thread_count,
  COALESCE((SELECT GROUP_CONCAT(thread_name, '; ') FROM producer_threads), '') as producer_thread_names,
  CASE
    WHEN (SELECT COUNT(*) FROM producer_threads WHERE thread_name IN ('1.ui', '1.raster', '1.io')) >= 2 THEN 'flutter_engine_threads'
    WHEN (SELECT COUNT(*) FROM producer_threads WHERE thread_name GLOB 'CrRendererMain*' OR thread_name GLOB 'VizCompositorThread*') > 0 THEN 'chromium_threads'
    WHEN (SELECT COUNT(*) FROM producer_threads WHERE thread_name = 'GameThread' OR thread_name = 'RHIThread' OR thread_name GLOB 'UnityMain*' OR thread_name GLOB 'UnityGfx*') > 0 THEN 'native_engine_threads'
    WHEN (SELECT COUNT(*) FROM producer_threads WHERE thread_name GLOB 'mqt_js*' OR thread_name GLOB 'mqt_native*') > 0 THEN 'react_native_threads'
    WHEN (SELECT COUNT(*) FROM producer_threads WHERE thread_name = 'RenderThread') > 0 THEN 'standard_renderthread'
    WHEN (SELECT COUNT(*) FROM producer_threads WHERE thread_name = 'main') > 0
         AND (SELECT COUNT(*) FROM producer_threads WHERE thread_name = 'RenderThread') = 0 THEN 'main_only_software'
    ELSE 'unknown'
  END as signature_type
