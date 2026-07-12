GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-pipeline-fences.template.md
Source SHA-256: 97025a7d1b0e7d930bf8d8d9aca16affb57d6f987a8c07cbf827957adac29b72
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

# Knowledge Pipeline Fences Template

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

# 3 种 Fence 详解（Article-Grounded）

本模板是 S01 §"三条 fence 的流向" + S05/S06 fence 三分法的完整详解。Agent 在涉及 fence 的诊断中必须明确用哪一种。

## 总览对比

| Fence | 方向 | 粒度 | 回答的问题 | 信号来源 |
|-------|------|------|-----------|---------|
| **acquire fence** | Producer → Consumer | per-buffer | GPU 写入完成？Consumer 何时安全读 | RT `queueBuffer` 时附上，SF latch 时等它 signal |
| **present fence** | HWC → SF | per-display per-frame | 这一整轮 present 何时扫描到屏幕 | HWC `getPresentFence()` 每次 present 一份 |
| **release fence** | HWC → Producer (经 SF/BQ) | per-layer per-frame | 上一帧 buffer 何时能被 Producer 安全复用 | HWC `getReleaseFences()` 每个 layer 一份，关联到上一轮 latch 的那块 buffer |

⚠️ **关键认知**：三种 fence 方向不同、粒度不同、问题不同——**不能混用**。

## 1. acquire fence

### 含义
Producer GPU 写入这块 buffer 何时完成。Consumer 读之前必须等它 signal，否则可能读到 GPU 半成品。

### 流向
```
RenderThread (Producer)
    ↓ queueBuffer 时附上 fence FD
BufferQueue
    ↓ buffer + fence 一起入队
SurfaceFlinger (Consumer)
    ↓ latch 时等 fence signal → acquireBuffer
```

### 触发等待
- 在 ⑧ latch 阶段：SF 等 acquire fence signal 后才把这层新内容采纳为本轮合成输入
- **latch unsignaled buffer 优化**（AutoSingleLayer）：单 layer 单 pending buffer 时可先 latch 推进流程，到读取 buffer 内容更后面阶段再等 fence——等待没消失，时机后移

### 常见问题
- **Producer GPU 写入慢** → acquire fence 晚 signal → SF latch 等待 → 该 layer 沿用旧内容
- **多 layer 场景**：某条独立 layer 的 acquire fence 晚 signal，SF 选择沿用该 layer 旧 buffer，引发"新旧混合"
- **TextureView 路径双层**：外部 Producer 的 acquire fence + 宿主自己窗口的 acquire fence 不能混淆

### 不适用场景
- **Software 路径**（lockCanvas/unlockCanvasAndPost）：acquire fence = `NO_FENCE`（CPU 写完即 ready，无 GPU 同步原语）
- **MediaCodec Tunneled**：HAL sideband stream 不经 App BufferQueue，无 acquire fence

## 2. present fence

### 含义
这一整轮 present 真正扫描到 panel 的时刻。这是端到端显示延迟最可靠的锚点。

### 流向
```
HWC presentDisplay()
    ↓ 每次 present 一份
HWC getPresentFence()
    ↓
SurfaceFlinger
    ↓ 用于回写"这一帧真正什么时候显示"
FrameTimeline / FrameMetrics / JankStats
```

### 关键事实
- **per-display per-frame**：每个 display 一份，每帧一份。多 layer / 多窗口场景下**不分 layer**——`present fence` 还是只有一份
- **回答的不是 buffer 状态**，是 display 控制器的扫描输出完成时刻

### 用途
- **分析"用户什么时候看到这一帧"**：必须用 present fence，不能用 queueBuffer 或 latch 时刻
- **校准系统帧节奏**：SF 根据真正显示完成时刻调整后续显示调度

### 常见问题
- **present fence 偏晚但 latch 不晚** → 问题在系统收尾阶段（Panel 模式切换 / 刷新率切换 / 扫描输出本身延迟 / DSI/DP 链路）
- **多窗口 / 多 layer 场景**：present fence 仍然只有一份，不要按对象去找

## 3. release fence

### 含义
HWC 何时不再使用上一轮 latch 的 buffer，buffer 何时可以被 Producer 安全复用。

### 流向
```
HWC presentDisplay() 完成后
    ↓ getReleaseFences() per-layer
SurfaceFlinger
    ↓ 经 BufferQueue 回传
Producer (App / Camera HAL / MediaCodec / etc)
    ↓ 下一次 dequeueBuffer 等它 signal 后才复用 slot
```

### 关键事实
- **per-layer per-frame**：每个 layer 一份，关联到**上一轮**已 latch 的那块 buffer
- **决定 dequeueBuffer 是否阻塞**：BufferSlot 4 状态（FREE/DEQUEUED/QUEUED/ACQUIRED）中 ACQUIRED → FREE 的转换由 release fence 触发

### 用途
- **分析"App 的 dequeueBuffer 为什么一直等"**：必须用 release fence，不能用 acquire/present fence
- **诊断多 Producer back-pressure**（Camera 多路输出场景）：哪个 consumer 的 release fence 晚回，哪条 capture pipeline 就 back-pressure

### 常见问题
- **dequeueBuffer 长等** → 上一帧 slot 卡 ACQUIRED 状态：HWC 还在显示该 layer / SF 这一轮没释放 / 可用 slot 数不够深
- **Camera ImageReader back-pressure**：App 不及时 `Image.close()` → ImageReader pool 满 → release fence 不回 → HAL 拿不到 buffer → capture pipeline 整体停摆

## 共同 fence 注意事项

### Software 路径不一定无 fence
- `unlockAndPost()` 提交时 acquire fence = NO_FENCE（CPU 写完即 ready），SF latch 不等
- **但 release fence 仍然存在**：HWC presentDisplay 后 getReleaseFences 仍返回，SF 经 BQ 回传给 Producer
- Producer 仍可能卡 dequeueBuffer 等 release（即使是软件路径）

### latch unsignaled buffer 不是跨 Surface 同步原语
- 仅适用于"单 layer 单 pending buffer + 无 sync transaction / geometry change"等条件
- 多 layer 同时更新、跨 Surface 同步场景下**不适用**
- 不能替多条 Producer 做同帧协调

### TextureView 双层 fence
- **外部 Producer 侧 fence**：保护"宿主 updateTexImage 时不读到 GPU 没写完的外部内容"
- **宿主窗口侧 fence**：保护"SF latch 时不读到宿主 GPU 没合成完的最终窗口结果"
- 两层不能混淆，问题诊断要分别追

### Tunneled 视频
- MediaCodec → HAL sideband stream → HWC（App 进程不参与）
- App 看不到 acquire/release fence——这些都在 HAL 层面
- 排查需要 HAL trace tag + HWC trace tag

## 诊断决策树

```
症状："用户看到画面晚"
    ↓
查 present fence 时刻 vs 应用 queueBuffer 时刻
    ↓
present fence 偏晚？
    ├─ Yes (latch 不晚) → 系统收尾段问题（panel/DVFS/扫描输出/HWC client composition）
    └─ No → 不是 fence 层面，是更早段问题

症状："App dequeueBuffer 阻塞"
    ↓
查上一帧 slot 状态 + release fence 时刻
    ↓
release fence 晚回？
    ├─ Yes → HWC 还在显示该 buffer / SF 没释放 / triple buffer 不足
    └─ No → 不是 release fence，是 BBQ depth 配置问题

症状："SF 读到半成品 / 跳帧"
    ↓
查 acquire fence signal 时刻 vs latch 时刻
    ↓
acquire fence 晚？
    ├─ Yes → Producer GPU 写入慢
    └─ No → 不是 acquire fence，是其他（latch unsignaled 时 fence 检查时机不同）
```

## 用法

Agent 在涉及 fence 的诊断中应：
1. **明确说哪一种 fence**（不能笼统说"fence 慢"）
2. **回到对应的方向、粒度、问题**
3. 区分 **TextureView 双层 fence**（外部 + 宿主）
4. **Software 路径不要忘 release fence 仍存在**
5. **Tunneled / 多 layer 场景下查 fence 要看对地方**
