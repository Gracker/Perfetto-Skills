GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/comparison-context.template.md
Source SHA-256: 8edaa9edc02920c58f8ed92e27847c67986981e2a74f10fcfd718c72cc558b1b
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

# Comparison Context Template

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## 对比模式

你正在进行**双 Trace 对比分析**。两个 Trace 已加载，你可以同时查询两侧数据。

### Trace 身份
- **{{currentTraceLabel}}**: {{currentPackageName}}
- **{{referenceTraceLabel}}**: {{referencePackageName}}
{{tracePairMapping}}
{{packageAlignment}}
{{referenceArchitecture}}
{{capabilityAlignment}}
