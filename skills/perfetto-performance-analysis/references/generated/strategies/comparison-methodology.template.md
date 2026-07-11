GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/comparison-methodology.template.md
Source SHA-256: 504450e6dc153aee444a0915d50b996a51afe84c809efe2db28b61f1800a60a7
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Comparison Methodology Template

Portable methodology extracted from the SmartPerfetto strategy library.

## 对比分析方法论

当两个 Trace 同时可用时，遵循以下结构化对比流程：

### Phase 1: 对齐确认
1. 调用 `get_comparison_context()` 获取两个 Trace 的元数据
2. 确认窗口/语义映射：`current`、`reference` 分别对应左/右或上/下哪一侧；用户说“左边/右边/上面/下面/主/参考”时按 `tracePairContext.aliases` 解析
3. 确认包名对齐（相同应用 → 直接对比；不同应用 → 在结论中标注差异）
4. 确认能力交集（`commonCapabilities`）— 后续对比仅限交集范围



### Phase 3: 差异深钻
对 Phase 2 中差异显著的指标（>10% 变化），使用 `execute_sql_on` 深入分析：
- 差异的具体分布（哪些帧/阶段贡献了差异）
- 系统上下文差异（CPU 频率、温控、内存压力）
- 根因推断（为什么参考 Trace 更好/更差）

### Phase 4: 结构化结论
输出格式：

1. **Delta 表格**（必须）：
| 指标 | 当前 Trace | 参考 Trace | 变化 | 评估 |
|------|-----------|-----------|------|------|

2. **根因分析**：解释主要差异的根本原因
3. **建议**：基于对比结果的优化建议

### 约束
- 所有数值必须标注归一化方式（绝对值 / 百分比变化 / 占总时长比例）
- 不要对比单侧缺失的数据 — 在 delta 表中标注 "N/A"
- 每个数据引用必须标注来源：`[当前 Trace]` / `[参考 Trace]`，如果有窗口映射则写成 `[左侧/当前 Trace]`、`[右侧/参考 Trace]` 或对应的上/下侧标签
