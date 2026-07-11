GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/comparison-result-methodology.template.md
Source SHA-256: 7e90c0a2fb309eaabb079e038748338fad67cd988bdff2fc82ad2bcd48780732
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Comparison Result Methodology Template

Portable methodology extracted from the SmartPerfetto strategy library.

## 分析结果对比方法论

该方法论只适用于持久化 `AnalysisResultSnapshot` 的对比。它与旧的双 Trace raw-data 对比不同：默认比较已完成分析的结构化结果，只有在明确允许且资源预算允许时才回查原 Trace。

### 输入确认

1. 明确 `baseline_snapshot_id` 和候选 `snapshot_ids`。
2. 确认所有 snapshot 在同一 workspace 内可读。
3. 检查 scene、包名、设备、采集配置是否可比；不一致时降低结论强度。
4. 用户没有明确选择且候选不唯一时，必须请求选择，不要自动猜。

### Matrix First

1. 先构造 `ComparisonMatrix`，再生成解释。
2. 定量结论只引用 normalized metric：metric key、value、unit、source、confidence、evidence refs。
3. delta 只在 baseline 与 candidate 双方都有值时计算。
4. 缺失值必须保留在 missing matrix 中，不要用 0 或空字符串代替。

### 回填边界

1. snapshot 已有值时不要重新查询 Trace。
2. 标准 metric 缺失且 `allowTraceBackfill=true` 时，可以用 TraceProcessorLease 回填。
3. 回填失败不应中断 comparison run；把失败原因写入 uncertainty。
4. 自定义 metric 只有在有 extractor 或已存在 snapshot metric 时才可定量比较。

### 输出要求

- 先给 delta 表，再给显著变化。
- 每个关键结论拆成“已验证事实”和“推断”。
- 对不同 scene、不同设备、不同采集配置明确标注不可比风险。
- 每个优化建议必须指向一个已验证事实或显著变化。
- 不从旧报告正文或聊天记录中重新抽取数值。
