# Perfetto Skills

[English](README.md)

这是一个可移植的 Perfetto 性能分析 Agent Skill，面向 Android、Linux 和
Chromium Trace。它把 SmartPerfetto 的领域工作流、SQL、能力门禁、身份/证据
规则和确定性 Skill runner 打包出来，但不依赖 SmartPerfetto 后端、Web UI、
模型 Provider、会话服务或 MCP Server。

## 如何选择 Perfetto 项目

这三个项目互为补充。按自己的使用方式选择最小合适入口；它们彼此都不是安装或
运行前置依赖。

| 项目 | 形态 | 最适合 | 主要边界 | 适合选择它的情况 |
|---|---|---|---|---|
| [SmartPerfetto](https://github.com/Gracker/SmartPerfetto) | 完整 Web UI、CLI 和后端 | 端到端、交互式 Android 性能排查 | 托管 Skill 运行时、报告、会话、对比和 Provider 集成 | 希望直接使用完整分析产品 |
| [Perfetto Skills](https://github.com/Gracker/Perfetto-Skills) | 可移植的标准 Agent Skill | 具备本地文件和终端能力的 Agent | 确定性本地 runner、证据契约和广泛分析工作流 | 希望在 Codex、Claude Code 或 OpenCode 中直接分析 Trace |
| [Google 官方 Perfetto Skill](https://github.com/google/perfetto/tree/main/ai/skills/perfetto) | 官方上游 Agent Skill bundle | 上游优先的 Trace 录制与分析 | 官方录制、内存、GPU 和通用 PerfettoSQL 指引 | 希望使用最轻量、由上游直接维护的入口 |

官方 Skill 的安装和发布方式见 Google 的
[Perfetto AI 使用文档](https://perfetto.dev/docs/getting-started/using-ai)。

## 它是不是标准 Skill？

是。`skills/perfetto-performance-analysis/SKILL.md` 遵循
[Agent Skills 规范](https://agentskills.io/specification)，包括标准 frontmatter、
渐进式引用目录和可独立发现的 Skill 根目录。

容易混淆的是：Agent Skills 规范定义 Skill 的目录与元数据，不规定安装器。
这里推荐的 `npx skills` 是 Vercel Labs 提供的生态安装工具；`tools/install.py`
只是离线安装或 Release 压缩包的 fallback。官方 Perfetto Skill 仅用于对照形式、
查询规范和查漏补缺，不是本项目的安装依赖、运行依赖或能力底座。

## 安装

当前验证过的 CLI 版本是 `1.5.16`。不带 `-g` 是项目级安装，只在当前项目可见；
带 `-g` 才是用户级全局安装。

先查看仓库能发现哪些 Skill，不执行安装：

```bash
npx skills@1.5.16 add Gracker/Perfetto-Skills --list
```

为当前项目的 Codex、Claude Code、OpenCode 安装：

```bash
npx skills@1.5.16 add Gracker/Perfetto-Skills \
  --skill perfetto-performance-analysis \
  -a codex -a claude-code -a opencode -y
```

全局安装：

```bash
npx skills@1.5.16 add Gracker/Perfetto-Skills \
  --skill perfetto-performance-analysis \
  -a codex -a claude-code -a opencode -g -y
```

检查、更新和卸载：

```bash
npx skills@1.5.16 list --json
npx skills@1.5.16 update perfetto-performance-analysis
npx skills@1.5.16 remove perfetto-performance-analysis -y
```

如果使用下载后的 Release 压缩包，可以使用离线 fallback：

```bash
python3 tools/install.py --client codex
python3 tools/install.py --client claude-code
python3 tools/install.py --client opencode
```

离线安装器默认不会覆盖已有目录，只有显式传 `--force` 才会替换。安装后刷新
Agent 客户端，然后让它用 `$perfetto-performance-analysis` 分析本地 `.pftrace`。

## 这次真正带走了什么

- 一个标准 `perfetto-performance-analysis` 路由和 14 个领域工作流。
- 230 个 SmartPerfetto 定义：198 个确定性可执行 Skill，31 个 pipeline 定义和
  1 个 comparison 契约明确标为 knowledge-only，不伪装成单 Trace 可执行 Skill。
- 637 条 SmartPerfetto 自研 SQL；每条都有来源、哈希、许可证、模块/fragment
  依赖、Android API 28–37 状态和四个独立验证轴。
- 便携执行层：输入/default、前置条件、身份门禁、`save_as`、条件、optional、
  empty/error 区分、`on_empty`、子 Skill、bounded iterator、确定性诊断和显式
  `agent_action_required` AI handoff。
- 3 个 SQL fragment、8 个 advisory-only 厂商启动 override、65 份 Strategy 来源、
  32 份渲染管线文档，以及带 SHA-256 锁定的跨平台 Trace Processor bootstrap。
- 一套项目自有真实 Trace fixture pack：来源、隐私扫描、逐文件哈希均不可变，另有
  一个提交进 Git、可离线运行的真实 smoke Trace。

## Android 9–17 / API 28–37 怎么保证

Android 版本不是 Trace schema 版本。系统 API、QPR、OEM、内核、Mainline 组件、
录制配置、实际 tag/event 和 Trace Processor 版本彼此独立。因此本项目不会写一个
笼统的“支持 Android 9–17”。每个 Skill、step 和 query 都有 API 28–37 条目，但
运行时按以下顺序判断：

1. 设备是否具备 data source、atrace category 或 ftrace event；
2. Trace config 是否启用，以及是否有 setup error；
3. 锁定的 Perfetto module、table、column 是否存在；
4. 目标进程/线程/时间范围内是否真的有数据；
5. 最后才把 API level 当作 adapter hint。

能力状态区分 `unsupported`、`not_recorded`、`recorded_empty`、
`recorded_populated`、`unknown`。表存在但零行不再被当成“已经录制”。当前项目
自有 fixture pack 覆盖 API 24、31、32、34、35、36，这仍不是 API 28–37
全覆盖。API 37 没有真实 Trace，因此只能是
`capability_gated`/`unknown`，不会冒充 `verified`。

## SQL 准确性怎么保证

637 条 SQL 来自 SmartPerfetto，不是“官方 Perfetto SQL”。官方仓库能保证的是
锁定的 Trace Processor、RPC API、stdlib 与 schema 真相，不能替代逐条语义验证。
本项目把保证拆成四个轴：

- `static_valid`：参数、fragment、依赖图、module 和表达式闭合；
- `runtime_compatible`：在锁定的官方 v57.2 / RPC API 14 上可解析、可执行；
- `execution_verified`：在有哈希的真实 fixture 上实际运行过；
- `semantic_verified`：fixture 还有列、值或关系断言，不只是“没有报错”。

官方 Perfetto Skill 的 stdlib-first、schema discovery、UPID/UTID、`dur = -1`
等规则会作为 gap-check 清单持续对照，但本项目保持自包含。v57.2 已通过本项目
的 binary hash、RPC API、module/schema 与 fixture 门禁；未来版本仍只先作为
canary，相同的 stdlib tree 也不能自动证明二进制和所有查询语义兼容。

## 开发验证

只需要 Python 3.11+ 和 `uv`。常规验证下载不可变的
[Perfetto Skills fixture pack](https://github.com/Gracker/Perfetto-Skills/releases/tag/fixtures-v2)，
不再依赖同级 SmartPerfetto checkout：

```bash
uv sync --extra dev
uv run python tools/verify.py
```

`uv run python tools/verify.py --offline` 只运行提交进 Git 的真实 smoke Trace。
SmartPerfetto 只在显式、锁定版本的导入检查中使用。三类上游同步与本地 SQL
red-green 修改流程见[上游同步文档](docs/maintenance/upstream-sync.md)。

运行清单按 Skill 分片，Agent 分析启动、滑动或 ANR 时不必加载全部 230 个定义。
更多信息见 [架构](docs/architecture.md)、[兼容性](docs/compatibility.md) 和
[迁移覆盖](docs/migration-coverage.md)。

## 许可证

SmartPerfetto 衍生内容使用 AGPL-3.0-or-later；上游 Perfetto 材料保留
Apache-2.0。详见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。
