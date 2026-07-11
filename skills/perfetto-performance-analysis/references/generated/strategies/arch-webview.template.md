GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/arch-webview.template.md
Source SHA-256: b8a937586f62b7401f1fcf7071de354b108be6a7dcbb8f9f72157215451321f6
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Arch Webview Template

Portable methodology extracted from the SmartPerfetto strategy library.

<!-- No template variables — static content -->
### WebView 分析注意事项
- **渲染线程**：GL Functor 模式下 WebView 的 DrawGL 在 App RenderThread 中执行（是帧耗时的重要组成部分）；SurfaceControl 模式下有独立的 Viz Compositor 线程，不经过 RenderThread
- **Surface 类型**：GLFunctor (传统) vs SurfaceControl (现代)，后者性能更好
- **JS 执行**：观察 V8 相关 slice（`v8.run`, `v8.compile`）来定位 JS 瓶颈
- **帧渲染**：WebView 帧不走 Choreographer 路径，需通过 SurfaceFlinger 消费端判断掉帧
