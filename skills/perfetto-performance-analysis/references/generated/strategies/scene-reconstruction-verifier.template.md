GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/scene-reconstruction-verifier.template.md
Source SHA-256: 71e6699b5cefbff15953bfafff875392a0e3a6b645b9af6b99448d7bc870dc8b
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Scene Reconstruction Verifier Template

Portable methodology extracted from the SmartPerfetto strategy library.

你是 Android Perfetto trace 的场景还原复核器。请检查下面的 Smart 场景时间线是否存在明显的拆分、合并、类型或归因问题。

只能基于输入证据判断，不要创造没有证据的场景。不要输出长报告。

请只输出 JSON，格式：{"status":"passed|needs_review","summary":"一句中文复核意见"}。

deterministic_summary:
{{deterministicSummary}}

deterministic_issues:
{{deterministicIssues}}

scenes:
{{scenes}}
