# Rendering-pipeline knowledge

Pipeline detection is architecture classification, not root-cause proof. Use
required signals, exclusions, and weighted signals from the generated
[pipeline definitions](../generated/pipelines/docs/index.md), then verify the
selected producer, buffer, compositor, fence, and display anchors in the trace.

Keep these boundaries distinct:

1. App/framework produces work on main, UI, raster, RenderThread, engine, or
   browser threads.
2. GPU and BufferQueue complete or transfer buffers.
3. SurfaceFlinger consumes layers and chooses GPU/HWC composition.
4. Present fences and display timing determine visibility.

A late app frame does not prove GPU saturation; a SurfaceFlinger miss does not
prove the app was on time; and a produced frame is not necessarily presented.
Report competing pipeline candidates when version or vendor naming weakens the
detection score.
