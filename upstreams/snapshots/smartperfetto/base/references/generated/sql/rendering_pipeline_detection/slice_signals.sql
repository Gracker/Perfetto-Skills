-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: daafcab67c375034945bafa954cdc6e4dc9e1a61942fb303a42d6abf593d817a
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH candidate_upids AS (
  SELECT DISTINCT p.upid
  FROM process p
  LEFT JOIN thread t ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND (
      '${package}' != ''
      OR t.name IN ('main', 'RenderThread')
      OR t.name GLOB '*ui*'
      OR t.name GLOB '*Flutter*'
      OR t.name GLOB '*Chrome*'
      OR t.name GLOB '*CrRenderer*'
      OR t.name GLOB '*Unity*'
    )
),
slice_counts AS (
  SELECT
    s.name as slice_name,
    COUNT(*) as cnt
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE p.upid IN (SELECT upid FROM candidate_upids)
  GROUP BY s.name
)
SELECT
  -- BLAST signals
  SUM(CASE WHEN slice_name GLOB '*BLASTBufferQueue*' THEN cnt ELSE 0 END) as blast_bq_count,
  SUM(CASE WHEN slice_name GLOB '*applyTransaction*' THEN cnt ELSE 0 END) as apply_transaction_count,
  SUM(CASE WHEN slice_name GLOB '*setTransactionState*' THEN cnt ELSE 0 END) as set_transaction_count,
  -- Standard HWUI signals
  SUM(CASE WHEN slice_name GLOB 'DrawFrame*' THEN cnt ELSE 0 END) as draw_frame_count,
  SUM(CASE WHEN slice_name GLOB '*syncFrameState*' THEN cnt ELSE 0 END) as sync_frame_count,
  SUM(CASE WHEN slice_name GLOB '*Choreographer#doFrame*' THEN cnt ELSE 0 END) as choreographer_count,
  SUM(CASE WHEN slice_name GLOB '*queueBuffer*' THEN cnt ELSE 0 END) as queue_buffer_count,
  SUM(CASE WHEN slice_name GLOB '*dequeueBuffer*' THEN cnt ELSE 0 END) as dequeue_buffer_count,
  -- Flutter signals
  SUM(CASE WHEN slice_name GLOB '*Flutter*' THEN cnt ELSE 0 END) as flutter_slice_count,
  SUM(CASE WHEN slice_name GLOB '*Engine::BeginFrame*' THEN cnt ELSE 0 END) as flutter_begin_frame_count,
  SUM(CASE WHEN slice_name GLOB '*Rasterizer*' THEN cnt ELSE 0 END) as flutter_rasterizer_count,
  SUM(CASE WHEN slice_name GLOB '*EntityPass*' OR slice_name GLOB '*InlinePassContext*' OR slice_name GLOB '*ImpellerValidationBreak*' THEN cnt ELSE 0 END) as impeller_entity_count,
  SUM(CASE WHEN slice_name GLOB '*SkGpu*' OR slice_name GLOB '*SkiaGpu*' OR slice_name GLOB '*GrGpu*' OR slice_name GLOB '*GrContext*' THEN cnt ELSE 0 END) as skia_gpu_count,
  -- WebView signals
  SUM(CASE WHEN slice_name GLOB '*DrawGL*' OR slice_name GLOB '*DrawFunctor*' THEN cnt ELSE 0 END) as draw_gl_functor_count,
  SUM(CASE WHEN slice_name GLOB '*Blink*' THEN cnt ELSE 0 END) as blink_count,
  SUM(CASE WHEN slice_name GLOB '*V8*' THEN cnt ELSE 0 END) as v8_count,
  SUM(CASE WHEN slice_name GLOB '*WebView*' THEN cnt ELSE 0 END) as webview_slice_count,
  -- Vulkan signals
  SUM(CASE WHEN slice_name GLOB '*vkQueuePresent*' THEN cnt ELSE 0 END) as vk_present_count,
  SUM(CASE WHEN slice_name GLOB '*Swappy*' THEN cnt ELSE 0 END) as swappy_count,
  SUM(CASE WHEN slice_name GLOB '*vkCmd*' THEN cnt ELSE 0 END) as vk_cmd_count,
  -- ANGLE signals
  SUM(CASE WHEN slice_name GLOB '*ANGLE*' THEN cnt ELSE 0 END) as angle_count,
  -- OpenGL signals
  SUM(CASE WHEN slice_name GLOB '*eglSwapBuffers*' THEN cnt ELSE 0 END) as egl_swap_count,
  SUM(CASE WHEN slice_name GLOB '*glDraw*' THEN cnt ELSE 0 END) as gl_draw_count,
  -- SurfaceView/TextureView signals
  SUM(CASE WHEN slice_name GLOB '*SurfaceView*' THEN cnt ELSE 0 END) as surfaceview_count,
  SUM(CASE WHEN slice_name GLOB '*SurfaceTexture*' OR slice_name GLOB '*updateTexImage*' THEN cnt ELSE 0 END) as texture_view_count,
  -- SurfaceControl signals
  SUM(CASE WHEN slice_name GLOB '*SurfaceControl*' THEN cnt ELSE 0 END) as surface_control_count,
  -- Game Engine signals
  SUM(CASE WHEN slice_name GLOB '*Unity*' THEN cnt ELSE 0 END) as unity_slice_count,
  SUM(CASE WHEN slice_name GLOB '*PlayerLoop*' THEN cnt ELSE 0 END) as unity_player_loop_count,
  SUM(CASE WHEN slice_name GLOB '*Unreal*' THEN cnt ELSE 0 END) as unreal_slice_count,
  -- Camera signals
  SUM(CASE WHEN slice_name GLOB '*Camera*' THEN cnt ELSE 0 END) as camera_slice_count,
  SUM(CASE WHEN slice_name GLOB '*CaptureSession*' THEN cnt ELSE 0 END) as capture_session_count,
  -- Video/HWC signals
  SUM(CASE WHEN slice_name GLOB '*MediaCodec*' OR slice_name GLOB '*Video*' THEN cnt ELSE 0 END) as video_slice_count,
  SUM(CASE WHEN slice_name GLOB '*HWC*' OR slice_name GLOB '*HardwareComposer*' THEN cnt ELSE 0 END) as hwc_slice_count,
  -- VRR/ARR signals
  SUM(CASE WHEN slice_name GLOB '*FrameTimeline*' THEN cnt ELSE 0 END) as frame_timeline_count,
  SUM(CASE WHEN slice_name GLOB '*setFrameRate*' OR slice_name GLOB '*FrameRateVote*' THEN cnt ELSE 0 END) as frame_rate_count,
  -- Software rendering signals
  SUM(CASE WHEN slice_name GLOB '*lockCanvas*' THEN cnt ELSE 0 END) as lock_canvas_count,
  -- Multi-window signals
  SUM(CASE WHEN slice_name GLOB '*Dialog*' OR slice_name GLOB '*PopupWindow*' THEN cnt ELSE 0 END) as dialog_count,
  -- PIP/Freeform signals
  SUM(CASE WHEN slice_name GLOB '*PictureInPicture*' OR slice_name GLOB '*PIP*' THEN cnt ELSE 0 END) as pip_count,
  -- X5/UC custom kernel signals
  SUM(CASE WHEN slice_name GLOB '*TBS*' OR slice_name GLOB '*X5*' OR slice_name GLOB '*UCCore*' THEN cnt ELSE 0 END) as custom_webview_count,
  -- HardwareBufferRenderer signals
  SUM(CASE WHEN slice_name GLOB '*HardwareBufferRenderer*' OR slice_name GLOB '*HBR*' THEN cnt ELSE 0 END) as hbr_count
FROM slice_counts
