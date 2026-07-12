GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/game_engine.skill.yaml
Source SHA-256: 05a9dac14c66dd06d2d975c93e7f89ffdedfc0a2ab905f4942c9db12a309258b
Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d
# 游戏引擎

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_game_engine
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: GAME_ENGINE
display_name: 游戏引擎
description: Unity/Unreal/Godot 等游戏引擎渲染
icon: gamepad
family: specialized
doc_path: rendering_pipelines/game_engine.md
s_article_ref: S13
four_features:
  producer_threads:
  - UnityMain
  - UnityGfx*
  - GameThread
  - RenderThread
  - RHIThread
  - GodotMain
  - TaskGraph*
  expected_layer_count: 1
  bufferqueue_path: ENGINE_SWAPCHAIN_TO_INDEPENDENT_SURFACE
  extra_rhythm_sources:
  - swappy_frame_pacing
  - engine_loop
  - achoreographer
deviation_anchors: engine_main_loop_anchor_2_3_4_5_6
subvariants_note: '文章 S13 把 Game 类型拆为 6 个子变种：

  - NATIVE_ENGINE_VULKAN（重度 3D 引擎，Vulkan swapchain）

  - NATIVE_ENGINE_GLES（GLES 路径）

  - NATIVE_ENGINE_SWAPPY（Swappy frame pacing 包装）

  - MINIGAME_CONTAINER（微信/抖音小游戏，JS + GLES）

  - CLOUD_GAME_DECODER（本地是解码 + SurfaceView，等同 S12）

  - XR_GAME_TIMEWARP（AR/VR，引擎 + Camera + SLAM + timewarp）

  Phase E 拆分独立 ID。当前 ID 主要覆盖 NATIVE_ENGINE_*。

  '
cross_frame_lag: 'Game/Render/RHI 三线程跨帧 lag（通常 1-3 帧）：每个时刻三线程在处理不同帧，

  不能按 wall-clock 对齐到"同一帧"，要用 frame_id marker 跨线程关联。

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_unity_main
  thread_pattern: UnityMain*
  weight: 85
- signal: has_unity_gfx
  thread_pattern: UnityGfx*
  weight: 85
- signal: has_unreal_game
  thread_pattern: GameThread*
  weight: 85
- signal: has_unreal_rhi
  thread_pattern: RHIThread*
  weight: 85
- signal: has_godot
  thread_pattern: GodotMain*
  weight: 80
- signal: has_cocos_lower
  thread_pattern: '*cocos*'
  weight: 35
- signal: has_cocos_upper
  thread_pattern: '*Cocos*'
  weight: 40
- signal: has_unity_slice
  slice_pattern: '*Unity*'
  weight: 45
- signal: has_player_loop
  slice_pattern: '*PlayerLoop*'
  weight: 30
- signal: has_unreal_slice
  slice_pattern: '*Unreal*'
  weight: 75
- signal: has_swappy
  slice_pattern: '*Swappy*'
  weight: 10
- signal: has_frame_pacing
  slice_pattern: '*FramePacing*'
  weight: 5
```

## Teaching model

```yaml
title: 游戏引擎渲染管线
summary: '游戏引擎 (Unity, Unreal, Godot) 有自己的游戏循环和渲染架构。

  通常有独立的游戏逻辑线程和渲染线程，使用 OpenGL/Vulkan 直接渲染。

  常结合 frame pacing / Choreographer / Swappy 控制节奏，

  帧率目标通常为 30/60/90/120 FPS。

  '
mermaid: "sequenceDiagram\n  participant Game as GameThread\n  participant Render as RenderThread/UnityGfx\n  participant\
  \ GPU as GPU Queue\n  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n\n\
  \  Note over Game,SF: \U0001F4CD Game Engine 渲染链路\n  Game->>Game: 游戏逻辑更新 (Physics/AI)\n  Game->>Render: 提交渲染任务\n\n  activate\
  \ Render\n  Render->>Render: 构建渲染命令\n  Render->>GPU: 提交 Draw Calls\n  GPU->>GPU: GPU 渲染\n  Render->>BQ: Present/SwapBuffers\n\
  \  deactivate Render\n\n  VS->>SF: \U0001F514 VSync-sf\n  activate SF\n  SF->>SF: latchBuffer\n  SF->>SF: HWC Composite\n\
  \  deactivate SF\n\n  Note over Game,SF: \U0001F3AE Unity/Unreal/Godot 等游戏引擎\n"
thread_roles:
- thread: UnityMain
  role: Unity 主线程
  description: Unity 游戏逻辑 + MonoBehaviour 脚本执行（Update/LateUpdate/FixedUpdate）
  trace_tags: PlayerLoop, Update, LateUpdate, FixedUpdate, MonoBehaviour
- thread: UnityGfx
  role: Unity 渲染线程
  description: Unity GPU 命令提交（Graphics API 调用、CommandBuffer 执行）
  trace_tags: GfxDevice, RenderThread, CommandBuffer
- thread: UnityMultiRenderingThread
  role: Unity 多线程渲染
  description: Unity Multithreaded Rendering 模式下的 GPU 命令提交线程（替代 UnityGfx）
  trace_tags: GfxDevice, Gfx.WaitForPresent
- thread: UnityJobWorker*
  role: Unity Job System 工作线程
  description: Unity ECS/DOTS 并行任务执行（Burst 编译的 IJobParallelFor、ISystem 等）
  trace_tags: JobHandle, BurstCompile, IJob
- thread: GameThread
  role: Unreal 游戏线程
  description: Unreal 游戏逻辑 + Blueprint 执行 + Tick 函数
  trace_tags: FEngineLoop, Tick, Blueprint
- thread: RenderThread
  role: Unreal 渲染线程
  description: Unreal 渲染命令生成（FRenderCommand 队列、Scene Proxy 更新）
  trace_tags: FRenderCommand, SceneProxy, DrawPolicy
- thread: RHIThread
  role: Unreal RHI 线程
  description: Unreal 渲染硬件接口 — GPU API 实际提交（Vulkan/GLES command submit）
  trace_tags: RHICmdList, SubmitCommandsHint, EndFrame
- thread: TaskGraph*
  role: Unreal TaskGraph 线程
  description: Unreal 异步任务系统（物理、动画、AI 等并行任务）
  trace_tags: FTaskGraphInterface, FAsyncTask
- thread: GodotMain
  role: Godot 主线程
  description: Godot 场景树遍历 + GDScript/C# 脚本执行 + 渲染命令生成
  trace_tags: MainLoop, SceneTree, _process, _physics_process
- thread: ServerThread
  role: Godot 物理线程
  description: Godot 物理引擎（Bullet/GodotPhysics）服务线程
  trace_tags: PhysicsServer, physics_process
- thread: CocosThread
  role: Cocos 引擎线程
  description: Cocos Creator/Cocos2d-x 游戏循环线程（如存在）
  trace_tags: Director, CCScheduler, CCRenderer
key_slices:
- name: PlayerLoop
  thread: UnityMain
  description: Unity 游戏循环入口 — 包含所有 MonoBehaviour 回调
- name: Update
  thread: UnityMain
  description: Unity MonoBehaviour.Update() 回调帧
- name: LateUpdate
  thread: UnityMain
  description: Unity MonoBehaviour.LateUpdate()，在所有 Update 后执行（常用于相机跟随）
- name: FixedUpdate
  thread: UnityMain
  description: Unity 物理步进回调，固定时间间隔触发
- name: GfxDevice
  thread: UnityGfx
  description: Unity 图形设备操作（draw call、state change）
- name: Gfx.WaitForPresent
  thread: UnityGfx
  description: Unity 等待 GPU 完成上一帧渲染（GPU bound 指标）
- name: FEngineLoop
  thread: GameThread
  description: Unreal 引擎主循环（包含 Tick、渲染提交、GC）
- name: TickGameWorld
  thread: GameThread
  description: Unreal 世界 Tick — 所有 Actor/Component 的 Tick 函数执行
- name: SubmitCommandsHint
  thread: RHIThread
  description: Unreal RHI 向 GPU 提交命令的标记点
- name: MainLoop
  thread: GodotMain
  description: Godot 主循环入口 — 场景树处理 + 渲染
- name: PhysicsServer
  thread: ServerThread
  description: Godot 物理服务器步进
- name: Swappy
  thread: '*'
  description: Android Frame Pacing Library（Google Swappy）— 帧节奏控制
- name: FramePacing
  thread: '*'
  description: 帧节奏/VSync 对齐标记
```

## Analysis guidance

```yaml
common_issues:
- id: cpu_bound
  name: CPU 瓶颈
  description: 游戏逻辑/物理/AI 过载
  detection_skill: cpu_analysis
- id: gpu_bound
  name: GPU 瓶颈
  description: DrawCall 过多或 Shader 复杂
  detection_skill: gpu_analysis
- id: triple_thread_attribution_required
  name: Game/Render/RHI 三线程归因
  description: 'UE: GameThread / RenderThread / RHIThread 三线程并行处理不同帧（cross-frame lag 通常 1-3 帧）。

    Unity: UnityMain / UnityGfx 双线程模型。任一线程超 budget 都拖整体 FPS。

    归因要按 frame_id marker 跨线程关联，不能按 wall-clock 对齐。

    '
  detection_skill: game_fps_analysis
- id: vk_acquire_next_image_blocked
  name: vkAcquireNextImageKHR 长等
  description: 'Native Vulkan 路径下 vkAcquireNextImageKHR 长等通常不是 GPU 慢——

    是 release fence 晚（HWC 消费慢）或 swapchain image 用完。

    '
  detection_skill: present_fence_timing
- id: swappy_frame_pacing_force_skip
  name: Swappy 强制跳帧到下个 vsync
  description: 'Swappy(SwappyVk_queuePresent / SwappyGL_swap) 检测到帧超 budget 时强制推迟到下个 vsync——

    这是设计行为，但导致有效帧率从 60→30。Trace 中表现为帧间隔从 16.67ms 突变 33.33ms。

    '
  detection_skill: vsync_phase_alignment
- id: pipeline_state_object_creation_jank
  name: PSO/pipeline 创建首帧卡顿
  description: 'Vulkan vkCreateGraphicsPipelines / GLES first-use shader compilation 引发首帧或首场景卡顿。

    缓解：pipeline cache、shader warmup、PSO 预热表。

    '
  detection_skill: jank_frame_detail
- id: hwc_client_fallback_due_to_overlay_competition
  name: 系统浮层挤占触发 HWC client composition
  description: 'Dialog/IME/Toast/system overlay 增加同屏 layer 数 → HWC plane 不够 → game layer 被打回 client composition →

    SF GPU 合成成本上升，挤占 game 自己的 GPU 预算。

    '
  detection_skill: sf_layer_count_in_range
recommended_skills:
- game_fps_analysis
- cpu_analysis
- gpu_analysis
- present_fence_timing
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (开始生产帧)
- pattern: UnityMain|UnityGfx|GameThread
  match_by: name
  priority: 2
  reason: 游戏引擎线程 (生产)
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的游戏引擎线程
- pattern: ^RenderThread(\s+\d+)?$
  match_by: name
  priority: 3
  reason: GPU 渲染 (传输)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的 RenderThread（部分引擎可能不使用）
- pattern: ^VSYNC-sf$
  match_by: name
  priority: 5.5
  reason: VSync (SurfaceFlinger 消费/合成)
- pattern: ^BufferTX
  match_by: name
  priority: 6
  reason: BufferTX (SurfaceFlinger 事务)
- pattern: ^[sS]urface[fF]linger
  match_by: name
  priority: 7
  reason: 最终合成/显示
  main_thread_only: true
```
