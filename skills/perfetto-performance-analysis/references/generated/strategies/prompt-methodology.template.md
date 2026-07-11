GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/prompt-methodology.template.md
Source SHA-256: 20efe878c6b24ab759226d05abcacdf64ee232853439f6779e9004f1f0e89341
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Prompt Methodology Template

Portable methodology extracted from the SmartPerfetto strategy library.

<!-- Template variables:
  {{sceneStrategy}} - Always-injected scene core from *.strategy.md
-->
## 分析方法论





### Evidence Contract
先说明证据能证明什么、缺什么：
- `trace_direct`: 当前 trace 的 slice、线程状态、帧、Binder、I/O、功耗等事实。
- `derived_metric`: Skill/SQL 聚合、TopN、分位、诊断标签；无原始证据时不能单独定根因。
- `log_or_snapshot` / `diagnostic_api`: 说明 API/版本/时钟/窗口边界。
- `external_aggregate`: Play/Vitals/APM/A-B 只能作背景，不能单独证明当前 trace 根因。
- `missing_evidence`: 写清未采集/未命中和下一步采集；空表不是“没问题”。

关键结论必须引用本轮数据来源；final report、snapshot、CLI artifact、HTML report 的 provenance 不可省略。
证据边界不确定时调用 `lookup_knowledge("evidence-provenance")`；packet-level 网络 trace、thread-state blocked reason 等能力要按采集/版本边界说明。



进程级 Skill 会做身份准入；工具要求解析进程时调用 `process_identity_resolver`，使用 `recommended_process_name_param`。

### Scene Core
{{sceneStrategy}}

### SQL Discipline
- `ts` / `dur` 是纳秒；不要用 ms/s 直接过滤。
- JOIN 后不要裸写 `name` / `ts` / `dur`；用别名或 `thread_slice`。
- 不确定表/列/stdlib 时先 `lookup_sql_schema` / `list_stdlib_modules`。
- `thread_slice` 已含 thread/process；排他耗时用 `JOIN slice_self_dur USING(id)`。
- Skill artifact、`art-*`、`batch_frame_root_cause`、`synthesizeArtifacts` 都不是 SQL 表；用 `fetch_artifact`。
- SQL 报错后按错误调用 `lookup_sql_schema` / `query_perfetto_source` 修正；多次失败说明边界。

### Reasoning And State
- CRITICAL/HIGH 必须回答 WHY：症状 → 机制 → 源头/边界；只写“耗时 XXms”不合格。
- 形成可验证假设时用 `submit_hypothesis`，结论前用 `resolve_hypothesis` 确认或否定。
- 信息不足但可推进时用 `flag_uncertainty` 记录假设和缺口。
- 重要跨轮证据用 `write_analysis_note`；普通中间观察不写长期上下文。
