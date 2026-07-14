# Perfetto Skills

[简体中文](README.zh-CN.md)

Portable Agent Skill for evidence-driven Android, Linux, and Chromium Perfetto
performance analysis. It packages SmartPerfetto's domain workflows, SQL,
capability gates, identity/evidence rules, and deterministic Skill runner
without requiring the SmartPerfetto backend, UI, provider runtime, or MCP
server.

<!-- android-performance-ecosystem:start -->
## Android performance ecosystem

This repository is one part of the [Android Performance Ecosystem](https://github.com/Gracker/android-performance-ecosystem): an optional path from instrumentation and capture to analysis, system knowledge, and reproducible cases.

| Stage | Project | Purpose | Address |
| --- | --- | --- | --- |
| Instrument | [TraceFix](https://github.com/Gracker/TraceFix) | Inject app-side android.os.Trace sections at build time so method work is visible at runtime. | [GitHub](https://github.com/Gracker/TraceFix) |
| Capture and measure | [Perfetto Tools](https://github.com/Gracker/perfetto-tools) | Capture repeatable Perfetto traces and collect FPS or Simpleperf measurements. | [GitHub](https://github.com/Gracker/perfetto-tools) |
| Analyze | [SmartPerfetto](https://github.com/Gracker/SmartPerfetto) | Investigate traces with an AI-assisted Web UI, CLI, reports, sessions, comparisons, and evidence workflow. | [GitHub](https://github.com/Gracker/SmartPerfetto) |
| Agent analysis | [Perfetto Skills](https://github.com/Gracker/Perfetto-Skills) | Give agents a portable Perfetto analysis Skill for Android, Linux, and Chromium, with selected assets synchronized through pinned workflows. | [GitHub](https://github.com/Gracker/Perfetto-Skills) |
| Learn | [Android Performance Blog](https://github.com/Gracker/Gracker.github.io) | Teach Perfetto and Systrace analysis through articles, system explanations, and case studies. | [GitHub](https://github.com/Gracker/Gracker.github.io) · [Website](https://www.androidperformance.com/) |
| System knowledge | Android Internal Wiki | An alpha knowledge base for Android mechanisms from App to Framework, Native, and Kernel. | **Coming soon** |
| Reproduce | [Trace for Blog (SystraceForBlog)](https://github.com/Gracker/SystraceForBlog) | Provide the Perfetto, Systrace, and related case files used by articles for hands-on reproduction. | [GitHub](https://github.com/Gracker/SystraceForBlog) |
<!-- android-performance-ecosystem:end -->

## Choose the right Perfetto project

These projects are complementary. Pick the smallest surface that matches how
you want to work; none is a prerequisite for another.

| Project | Form | Best for | Main boundary | Choose it when |
|---|---|---|---|---|
| [SmartPerfetto](https://github.com/Gracker/SmartPerfetto) | Full Web UI, CLI, and backend | End-to-end interactive Android investigations | Managed Skill runtime, reports, sessions, comparisons, and provider integration | You want a complete analysis product |
| [Perfetto Skills](https://github.com/Gracker/Perfetto-Skills) | Portable standard Agent Skill | Local agents with filesystem and terminal access | Deterministic local runner, evidence contracts, and broad analysis workflows | You want trace analysis inside Codex, Claude Code, or OpenCode |
| [Google official Perfetto Skill](https://github.com/google/perfetto/tree/main/ai/skills/perfetto) | Official upstream Agent Skill bundle | Upstream-first trace recording and analysis | Official recording, memory, GPU, and ad-hoc PerfettoSQL guidance | You want the smallest upstream-maintained starting point |

See Google's [official Perfetto AI usage guide](https://perfetto.dev/docs/getting-started/using-ai)
for the upstream Skill installation and release model.

## Is this a standard Agent Skill?

Yes. `skills/perfetto-performance-analysis/SKILL.md` follows the
[Agent Skills specification](https://agentskills.io/specification), including
standard frontmatter and progressive references. The specification defines the
Skill directory and metadata; it does not prescribe an installer.

The commands below use Vercel Labs' ecosystem `skills` CLI as the recommended
convenience installer. `tools/install.py` remains an offline/release-archive
fallback. The official Perfetto Skill is used only as a gap-checking reference;
it is neither an install nor runtime dependency.

## Install

The verified CLI version is `1.5.16`. Project installs are visible only in the
current project; add `-g` for a user-level install.

Inspect the repository without installing:

```bash
npx skills@1.5.16 add Gracker/Perfetto-Skills --list
```

Install for Codex, Claude Code, and OpenCode in the current project:

```bash
npx skills@1.5.16 add Gracker/Perfetto-Skills \
  --skill perfetto-performance-analysis \
  -a codex -a claude-code -a opencode -y
```

Install globally:

```bash
npx skills@1.5.16 add Gracker/Perfetto-Skills \
  --skill perfetto-performance-analysis \
  -a codex -a claude-code -a opencode -g -y
```

Verify, update, or remove:

```bash
npx skills@1.5.16 list --json
npx skills@1.5.16 update perfetto-performance-analysis
npx skills@1.5.16 remove perfetto-performance-analysis -y
```

For an extracted release archive, run one of:

```bash
python3 tools/install.py --client codex
python3 tools/install.py --client claude-code
python3 tools/install.py --client opencode
```

The fallback never overwrites an install unless `--force` is explicit. After
installation, refresh the client and ask it to use
`$perfetto-performance-analysis` on a local `.pftrace` file.

## What is included

- One standard `perfetto-performance-analysis` router and 14 workflows.
- 230 SmartPerfetto definitions: 198 deterministic executable Skills and 32
  knowledge-only pipeline/comparison contracts.
- 637 SmartPerfetto-authored SQL queries, each with source/hash/license,
  module/fragment dependencies, Android API 28–37 status, and four independent
  validation axes.
- A safe expression runtime for all authored conditions, child-Skill calls,
  bounded iterators, diagnostics, explicit AI handoffs, evidence sidecars, and
  report validation.
- Three SQL fragments, eight advisory-only OEM startup overrides, 65 strategy
  sources, and 32 rendering-pipeline documents.
- A checksum-pinned cross-platform trace processor bootstrap.
- A project-owned real-trace fixture pack with immutable provenance, privacy
  scan evidence, per-file hashes, and a committed offline smoke trace.

The SQL is not described as "official Perfetto SQL." It is SmartPerfetto SQL
executed against a locked official Perfetto runtime. Queries without exact
fixtures remain capability-gated or unverified, and cannot support a verified
causal conclusion merely because they parse.

## Development

Requirements: Python 3.11+ and `uv`. Normal development downloads the immutable
[Perfetto Skills fixture pack](https://github.com/Gracker/Perfetto-Skills/releases/tag/fixtures-v2)
and does not require a SmartPerfetto checkout.

```bash
uv sync --extra dev
uv run python tools/verify.py
```

Use `uv run python tools/verify.py --offline` for the committed real smoke
trace. SmartPerfetto is needed only for an explicit pinned import review; the
three upstream sync procedures and local SQL red-green workflow are documented
in [upstream synchronization](docs/maintenance/upstream-sync.md).

Generated runtime indexes are sharded by Skill so agents load only the selected
workflow/query. See [architecture](docs/architecture.md),
[compatibility](docs/compatibility.md), and
[migration coverage](docs/migration-coverage.md).

## Releases and license

Tagged releases contain reproducible `.zip` and `.tar.gz` bundles plus
`SHA256SUMS`. Trace processor executables and trace fixtures are not bundled.
The separately versioned fixture pack is a test asset, not an install/runtime
dependency of the Skill archive.
SmartPerfetto-derived work is AGPL-3.0-or-later; upstream Perfetto material
retains Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
