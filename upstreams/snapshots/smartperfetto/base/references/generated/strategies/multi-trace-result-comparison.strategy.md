GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/multi-trace-result-comparison.strategy.md
Source SHA-256: d5d5f1054761c3838d03ffcf3d25d15cd48044b3e3114e2039ba58fd97427d25
Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

# Multi Trace Result Comparison Strategy

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
scene: multi_trace_result_comparison
classification_description: Comparing previously saved analysis results or snapshots, including scope and metric differences
  between results.
priority: 0
effort: medium
required_capabilities: []
optional_capabilities: []
keywords:
- 分析结果对比
- 结果对比
- 多 Trace 结果对比
- 多 trace 结果对比
- 多个 Trace 结果对比
- 两个 Trace 结果对比
- 另一个 Trace 的分析结果
- 另外一个 Trace 的分析结果
- snapshot 对比
- SID 对比
- analysis result comparison
- result comparison
- multi trace result comparison
- compare snapshots
- compare analysis results
phase_hints:
- id: result_snapshot_selection
  keywords:
  - snapshot
  - 结果
  - 候选
  - baseline
  - current result
  - analysis result
  critical_tools: []
  critical: true
- id: matrix_first
  keywords:
  - matrix
  - delta
  - metric
  - fps
  - jank
  - startup
  - 启动
  - 帧率
  constraints: 定量结论只能来自 ComparisonMatrix 的 normalized metrics。缺失 metric 要标注 missing reason；只有允许回填时才请求 trace backfill。
  critical_tools: []
  critical: true
plan_template:
  mandatory_aspects:
  - id: snapshot_scope
    match_keywords:
    - snapshot
    - analysis result
    - 结果
    - baseline
    - candidate
    suggestion: 分析结果对比必须先确认 snapshot 范围、baseline 和 candidates
    required_expected_calls:
    - {}
  - id: comparison_matrix
    match_keywords:
    - matrix
    - metric
    - delta
    - fps
    - jank
    - startup
    - 启动
    - 帧率
    suggestion: 分析结果对比必须构造 ComparisonMatrix，并基于结构化 metric 输出 delta
    required_expected_calls:
    - skill_id: multi_trace_result_comparison
```

## Investigation methodology

Apply `result_comparison` version 1 from [shared investigation methods](investigation-profiles.yaml.md).

Apply `causal_reasoning` version 1 from [shared investigation methods](investigation-profiles.yaml.md).

### multi_trace_result_comparison_critical_path (critical_path)

Retain each saved snapshot identity, original scene, scope and evidence pin. Compare stored app and system findings in their original windows; missing investigation coverage remains unknown.

### multi_trace_result_comparison_dependencies (dependency_chain)

Explain compatible deltas, alternatives and incomparable dimensions using saved artifacts. Do not query original traces, reinterpret missing values as zero, or generalize one side coverage to the pair.

#### multi_trace_result_comparison Core Strategy

**Route card**: 分析结果对比 / 结果对比 / 多 Trace 结果对比 / 多个 Trace 结果对比 / 两个 Trace 结果对比 / snapshot 对比 / SID 对比 / analysis result comparison / result comparison

**Capabilities**: required=[none], optional=[none]

**Final report contract summary**
- 遵循通用输出契约。


<!-- strategy-detail id="full" title="multi_trace_result_comparison full strategy detail" keywords="multi_trace_result_comparison,分析结果对比,结果对比,多 Trace 结果对比,多 trace 结果对比,多个 Trace 结果对比,两个 Trace 结果对比,snapshot 对比,SID 对比,analysis result comparison,result comparison,multi trace result comparison,compare snapshots,分析结果对比（用户提到多个 Trace 的已有分析结果、snapshot、SID/result、另一个 Trace 的分析结果）,detail,full" default="true" -->
#### 分析结果对比（用户提到多个 Trace 的已有分析结果、snapshot、SID/result、另一个 Trace 的分析结果）

这是多窗口/多用户结果快照对比，不是当前会话里已打开两个 Trace 的实时 raw data 对比。

**Phase 1 — Snapshot 范围确认：**

- 当前窗口已有 latest snapshot 时，把它作为默认 baseline 候选。
- 通过结果目录或候选选择器确认其他可读 snapshot。
- 候选唯一时可以直接发起 comparison；候选不唯一时必须让用户确认。
- baseline 必须明确；不要把“当前 Trace”隐式当成所有场景的 baseline。

**Phase 2 — 构造 ComparisonMatrix：**

**Phase 3 — 缺失与回填：**

- snapshot 已有 metric 时优先使用快照值。
- snapshot 缺少标准 metric，且用户或策略允许回填时，才能回查原 Trace。
- 回填失败时 comparison 仍完成，并把失败原因写入 missing matrix / uncertainty。
- 自定义 metric 没有定义 extractor 时不要硬算，返回不支持或缺失原因。

**Phase 4 — 结论输出：**

输出必须包含：

1. `ComparisonMatrix` delta 表，包含 baseline、candidate 值、delta、deltaPct 和 trend。
2. 显著变化列表，只列出有结构化证据的变化。
3. 不可比/缺失/回填失败说明。
4. AI 解释分为“已验证事实”和“推断”，推断必须基于 matrix 中的事实。

禁止：
