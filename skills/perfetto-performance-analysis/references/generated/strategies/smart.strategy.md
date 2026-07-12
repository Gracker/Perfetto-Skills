GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/smart.strategy.md
Source SHA-256: 85a09187e5ab929984ba5b0897d330595a777ea27c6c101c1f29661a95181870
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

# Smart Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

## Portable strategy metadata

```yaml
scene: smart
strategy_kind: contract_only
priority: 5
effort: high
keywords:
- smart
- 智能
- mixed trace
- 场景混合
required_capabilities: []
optional_capabilities: []
final_report_contract:
  required_sections:
  - id: scene_timeline
    label: 场景时间线
    description: 按时间顺序列出 trace 中检测到的关键用户操作和设备状态场景。
    pattern_groups:
    - - 场景时间线
      - timeline
      - 时间线
    - - 冷启动
      - 热启动
      - 滑动
      - 点击
      - 返回
      - Home
      - 亮屏
      - 熄屏
      - ANR
  - id: per_scene_summary
    label: 分场景摘要
    description: 对每个被深度分析的场景给出关键指标、结论和证据引用。
    pattern_groups:
    - - 分场景
      - 逐场景
      - per-scene
    - - 证据
      - 指标
      - 耗时
      - 延迟
      - 帧
  - id: cross_scene_narrative
    label: 跨场景叙事
    description: 总结多个场景之间的关联、共同瓶颈或前后影响。
    pattern_groups:
    - - 跨场景
      - 整体
      - 关联
      - 链路
    - - 原因
      - 影响
      - 共同
      - 瓶颈
  - id: bottleneck_ranking
    label: 瓶颈排序
    description: 按影响范围、严重度和可行动性给出优化优先级。
    pattern_groups:
    - - 瓶颈排序
      - 优先级
      - ranking
    - - P0
      - P1
      - 优先
      - 建议
```

# Smart Analysis Contract

This strategy is intentionally contract-only. It must not be injected as a
normal scene strategy and must not participate in scene classification.

Smart Analysis Mode combines Scene Story detection with profile-specific
deep-dive routes, then projects the resulting scene report into a readable chat
summary and the standard HTML report chain.
