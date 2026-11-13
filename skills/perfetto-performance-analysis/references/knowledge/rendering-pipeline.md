# Rendering-pipeline knowledge

Pipeline detection is architecture classification, not root-cause proof. Use
required signals, exclusions, and weighted signals from the generated
[local product teaching cards](../generated/knowledge/rendering-teaching.md) and
candidate definitions under `../generated/skills/`, then verify the
selected producer, buffer, compositor, fence, and display anchors in the trace.

Keep these boundaries distinct:

1. App/framework produces work on main, UI, raster, RenderThread, engine, or
   browser threads.
2. GPU completion, resource transfer, and BufferQueue consumption are separate
   observations. BLASTBufferQueue consumes on the app side; a received buffer
   update is not a completed GPU job or a displayed frame.
3. SurfaceFlinger handles layer updates and chooses GPU/HWC composition.
4. Present fences and display timing determine visibility.

A late app frame does not prove GPU saturation; a SurfaceFlinger miss does not
prove the app was on time; and a produced frame is not necessarily presented.
Report competing pipeline candidates when version or vendor naming weakens the
detection score.

Use the bundled cards without loading reference articles or another checkout.
Only scheduling wakeups or explicit object/flow evidence establish observed
dependencies; the static card diagram is not an inferred trace graph. Read the
[output and resource boundaries](../generated/knowledge/knowledge-rendering-outputs.template.md)
for multiple outputs, front buffers, capture, system animation, and resource
release timing.
