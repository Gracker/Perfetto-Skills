GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-rendering-pipeline.template.md
Source SHA-256: d023a81db374c2388971668123ec4edd51bed96ce738f9bdc9e178160db53622
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

# Knowledge Rendering Pipeline Template

Portable methodology extracted from the SmartPerfetto strategy library.

# Android 出图机制（Article-Grounded）

本知识库基于 Android Perfetto 出图类型系列文章 S01-S14，建立"12 锚点 + 3 fence + 4 特征分型 + 5 瓶颈模式 + 17 类型"统一框架。Agent 在任何 pipeline 相关诊断中都应回到这个框架。

## 12 锚点基线（S01）

一帧从触发到上屏走过 12 个关键节点。后续 17 类型都按"相对基线偏离哪几个锚点"来描述。

```
① vsync-app                  →  SF Scheduler 按 app workDuration 回调
② Choreographer.doFrame      →  5 callbacks: INPUT → ANIMATION → INSETS_ANIMATION → TRAVERSAL → COMMIT
③ syncAndDrawFrame           →  UI Thread → RenderThread 交接（不是 callback 类型，是 TRAVERSAL 末尾的边界）
④ dequeueBuffer              →  RenderThread 从 BBQ 取可写 buffer slot
⑤ Skia/GPU                   →  Skia pipeline 录制 + GPU 命令提交
⑥ queueBuffer→Transaction    →  BBQ 把 buffer + 窗口状态打包成 Transaction 给 SF
                                  ⚠️ BufferTx counter 在此 +1（SF 侧 Transaction 到达时），不在 queueBuffer 返回时
⑦ vsync-sf                   →  SF Scheduler 按 sf workDuration 起跑
⑧ latch                      →  SF acquireBuffer（等 acquire fence signal 后采纳）
⑨ HWC validate               →  validateDisplay → getChangedCompositionTypes → acceptDisplayChanges
⑩ client composition         →  按需，被 HWC 降级的 layer 由 SF 用 GPU 合成到 client target
⑪ presentDisplay             →  HWC 调用，per-display per-frame
⑫ scan-out + present fence   →  Display 把帧扫到屏幕，present fence signal
```

详细每个锚点的工作机制和常见问题，参考 `knowledge-pipeline-anchors.template.md`。

## 3 种 fence

每种 fence 方向不同、粒度不同、回答的问题也不同。Agent 在 jank 归因时必须明确用哪一种。

| Fence | 方向 | 粒度 | 回答的问题 |
|-------|------|------|-----------|
| **acquire fence** | Producer → Consumer | per-buffer | 这块 buffer 的 GPU 写入什么时候完成，Consumer 何时能安全读 |
| **present fence** | HWC → SF | per-display per-frame | 这一整轮 present 什么时候真正扫描到屏幕（端到端显示延迟最可靠锚点） |
| **release fence** | HWC → Producer (经 SF) | per-layer per-frame | 上一帧的 buffer 什么时候能被 Producer 安全复用 |

**典型用法**：
- 分析"用户什么时候看到这一帧"用 **present fence**
- 分析"App 的 dequeueBuffer 为什么一直等"用 **release fence**
- 分析"SF 读到半成品 / 等 GPU 写完"才去怀疑 **acquire fence**

详细 fence 流向、流量、常见问题，参考 `knowledge-pipeline-fences.template.md`。

## 4 特征分型（S01）

每条 trace 在分析前先用 4 个独立维度分型，避免误判：

| 特征 | 决定性问题 | rendering_pipeline_detection 输出字段 |
|------|-----------|------------------------------------|
| 1. **Producer 线程数** | 应用进程里有几条主要的 Producer 线程？ | `subvariants.flutter_engine` / `subvariants.game_engine` 等 |
| 2. **Layer 数** | 在 SurfaceFlinger 进程下，与该 App 相关的 layer 有几个？ | `layer_signals.app_layer_count` / `layer_signals.app_layer_names` |
| 3. **queueBuffer 路径** | buffer 是怎样到 SF 的（BBQ→Transaction / 跨进程独立 BufferQueue / 回宿主采样 / Software 直 Surface / SurfaceControl 直推）？ | `bufferqueue_path_signals.bufferqueue_path` |
| 4. **额外节奏点** | 有没有 vsync-app 之外的节奏来源（Swappy/AChoreographer/Camera HAL/setFrameRate voting）？ | `extra_rhythm_signals.primary_rhythm_source` |

**4 维同时对得上**，分型基本就定了。再去看具体线程和切片，方向就不容易错。

## 5 瓶颈模式（S01）

这条主链上最常见的 5 类瓶颈位置。每一类对应一组特征切片，看到对应特征再深入查根因，比一上来按线程找最长 slice 更省时间。

| 模式 | 特征切片 | 第一怀疑 |
|------|----------|----------|
| MainThread 超预算 | `Choreographer#doFrame` 内某段（INPUT/ANIMATION/TRAVERSAL）持续超 8-10ms | 主线程上有同步 IO、layout 重算、过深 View 树 |
| RenderThread 等 buffer | `dequeueBuffer` 长等，前一帧 release fence 未回 | SF 侧消费慢、triple buffer 不足、上一帧仍被占用 |
| SF 侧消费跟不上 | `BufferTX` 长期偏高、latch 滞后 | SF Duration 抬升；HWC 把更多 layer 打回 client 合成 |
| HWC 决策回退 | SF 进程出现 `client composition` 切片，原本 DEVICE 的 layer 被降级 | 透明、旋转、受保护内容、layer 过多触发降级 |
| 显示输出延迟 | `present fence` 偏晚，但 latch 不晚 | Panel 模式切换、刷新率切换、扫描输出本身延后 |

## 17+ 出图类型对照表





## 通用诊断流程

按以下顺序，先把"问题发生在帧节奏 / 生产 / 消费 / 显示"四层分清，再深入：

```
1. 看 vsync-app / Choreographer#doFrame / FrameTimeline 的开始点 → App 是不是起晚了
2. 看 INPUT/ANIMATION/TRAVERSAL/COMMIT 哪一段膨胀 + RenderThread 是真忙还是在等
3. 看 BufferTX / latch / SurfaceFlinger 事件 → 系统在等新 buffer 还是消化不过来
4. 看 fence / HWC / present fence / panel → 内容已经交出去为什么用户还是晚看到
```

## SQL 快速量化

```sql
-- 所有 jank 帧
SELECT ts, dur, name, jank_type, layer_name
FROM actual_frame_timeline_slice
WHERE jank_type != 'None'
ORDER BY ts;

-- 按 jank 来源（App / SF）分组统计
INCLUDE PERFETTO MODULE android.frames.jank_type;
SELECT
  CASE
    WHEN android_is_app_jank_type(jank_type) THEN 'App'
    WHEN android_is_sf_jank_type(jank_type)  THEN 'SF'
    ELSE 'Other'
  END AS source,
  COUNT(*) AS jank_frames
FROM actual_frame_timeline_slice
WHERE jank_type != 'None'
GROUP BY source;
```



每个 pipeline yaml 在 `meta` 中标注了：
- `s_article_ref`: 对应文章（S02/S03/...）
- `four_features`: 4 特征分型签名
- `deviation_anchors`: 偏离 12 锚点的哪几个

`rendering_pipeline_detection` skill 的 4 个步骤分别输出：
- `pipeline_result`: 主管线 + confidence + candidates
- `subvariants`: 子变体（buffer_mode / flutter_engine / webview_mode / game_engine）
- `layer_signals`: SF 侧 layer 信号（4 特征 #2）
- `extra_rhythm_signals`: 额外节奏源（4 特征 #4）
- `bufferqueue_path_signals`: BufferQueue 路径（4 特征 #3）
- `active_rendering_processes`: 活跃渲染进程
