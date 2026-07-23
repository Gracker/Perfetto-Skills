GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-pipeline-anchors.template.md
Source SHA-256: 398f2233633ac13b9932f6bf6563ea6b68ae20615868ed42d4ba205dc0970c56
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

# Knowledge Pipeline Anchors Template

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

# Android 17 渲染锚点使用规则

锚点语义以 `docs/rendering_pipelines/S01_rendering_types_overview.md` 和当前
类型文章为准。本模板只规定诊断方法，避免复制一份会随 Android 演进而失真的
固定步骤表。

## 先画实际对象树

先确认 Producer、最终可见 Surface/layer、宿主回流、独立 child layer、
BufferQueue/transaction 与 display。Flutter PlatformView、Camera、WebView、
多窗口和视频页面都可能同时存在多条节拍，不能把某个框架线程当成唯一帧。

## 再对齐四段时间

1. **触发与生产**：VSync/callback、main/UI、framework/engine、RenderThread 或
   自定义 producer；
2. **提交与可读**：dequeue、GPU/CPU work、queue/transaction、acquire fence；
3. **采纳与合成**：SF state/latch、layer snapshot、RenderEngine/HWC 分工；
4. **显示反馈**：present/release fence 与下一轮 buffer 复用。

每个结论都要引用实际 slice、thread/process、layer/buffer/token 和时间戳。
`queueBuffer` 完成不等于 SF 已采纳，SF 已采纳不等于 display 已 present，
present feedback 也不等于 panel 光学完成或用户感知。

## Android 12—17 边界

- Android 12 是现代 BLAST/FrameTimeline 分析基线，不是“Legacy 默认”。
- Android 13 的 latch-unsignaled 让部分 fence wait 后移；等待并未消失。
- Android 17 的 HWC 流程需按 `presentOrValidate` 实际分支解释；不要套用
  无条件 validate 序列。
- 框架/engine/provider 随 App 发布时，要同时记录 Android build 与对应版本。

## 归因纪律

- 先定位是哪一段晚，再找该段的 Running、Runnable、Blocked、GPU 或 fence
  证据；
- absence 只能写成缺失或未采集，不能写成“没有该机制”；
- feature 信号不能覆盖主类型证据；
- 类型特有的最小证据和误判边界必须回到 S02-S14 原文。
