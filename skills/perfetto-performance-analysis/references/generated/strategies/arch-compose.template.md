GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/arch-compose.template.md
Source SHA-256: 6a46163bb5da7bba10ce66b7617c3f8a87851185766c0a8221e185e5e05308cb
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

# Arch Compose Template

Portable methodology extracted from the SmartPerfetto strategy library.

<!-- No template variables — static content -->
### Jetpack Compose 分析注意事项
- **Recomposition**：关注 `Recomposer:recompose` slice 频率和耗时，频繁重组是性能杀手
- **LazyList**：`LazyColumn`/`LazyRow` 的 `prefetch` 和 `compose` 子 slice 影响滑动流畅度
- **Hybrid View**：如果 isHybridView=true，传统 View 和 Compose 混合渲染，需关注 `choreographer#doFrame` 中的 Compose 耗时
- **State 读取**：过多的 State 读取（尤其在 Layout 阶段）会触发不必要的重组
- **线程模型**：与标准 Android 相同（MainThread + RenderThread），但 Compose 的 Layout/Composition 阶段在 MainThread
