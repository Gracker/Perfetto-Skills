GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-harmonyos-rendering.template.md
Source SHA-256: a35f16d1313d5eb713799b17d3f0876ac83e0c3af1fa8f139d943e9845bd3b2e
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

# Knowledge Harmonyos Rendering Template

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
<!-- Copyright (C) 2024-2026 Gracker (Chris) | the portable runtime -->

# HarmonyOS 渲染管线（RS 三级流水线）

HarmonyOS 使用 RenderService (RS) 三级流水线架构，与 Android 的 SurfaceFlinger + Choreographer 模型有本质区别。Agent 分析 HarmonyOS 渲染性能时必须基于此模型。

## 三级流水线

```
① App 侧（UI Thread）
   → ArkTS/JS UI 框架构建组件树
   → ace::Component::Build / ace::Component::Update
   → 生成 RS 指令 (RSCommand) 并发送到 RS 进程

② RS 侧（RenderService 进程）
   → RSRenderThread 接收 App 的 RSCommand
   → 分为 2D 和 3D 渲染路径
   → 2D: CPU 渲染 (Skia CPU)
   → 3D: GPU 渲染 (Skia GPU / Vulkan)
   → RSRender::Process → RSRender::RenderFrame

③ GPU 侧
   → GPU 合成 (RS 直接提交 GPU 命令)
   → 不经过独立 compositor 进程
   → Direct rendering 到 display
```

## 与 Android 渲染的区别

| 维度 | Android | HarmonyOS |
|------|---------|-----------|
| 渲染架构 | App → SurfaceFlinger → HWC | App → RS → GPU (无独立 compositor) |
| UI 框架 | View 系统 / Jetpack Compose | ArkUI (ace:: 框架) |
| 帧调度 | Choreographer + Vsync | Vsync + RS 调度 |
| 动画 | android.animation | ArkUI 动画系统 |

## 常见渲染瓶颈

1. **App 侧慢**：组件树更新耗时，ace::Component::Update 超过 Vsync 间隔
2. **RS 侧慢**：复杂效果（blur/shadow/effect）导致 RS 渲染帧超时
3. **GPU 侧慢**：过度绘制、大纹理、shader 复杂度高

## 关键 tracing_mark_write 标签

HarmonyOS ftrace 文本中，Slice 表的 name 列包含以下独有标签：

| 标签 | 含义 |
|------|------|
| `ace::Component::Build` | ArkUI 组件构建 |
| `ace::Component::Update` | ArkUI 组件更新 |
| `RSRender::RenderFrame` | RS 渲染帧 |
| `FFRT::*` | FFRT 任务调度 |
| `H:FunctionName` | hitrace 用户态函数标记 |
