# Perfetto Skills

[简体中文](README.zh-CN.md)

Portable Agent Skill for evidence-driven Android, Linux, and Chromium Perfetto
performance analysis. It packages SmartPerfetto's domain workflows, SQL,
capability gates, identity/evidence rules, and deterministic Skill runner
without requiring the SmartPerfetto backend, UI, provider runtime, or MCP
server.

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

The SQL is not described as "official Perfetto SQL." It is SmartPerfetto SQL
executed against a locked official Perfetto runtime. Queries without exact
fixtures remain capability-gated or unverified, and cannot support a verified
causal conclusion merely because they parse.

## Development

Requirements: Python 3.11+, `uv`, and a sibling SmartPerfetto checkout for
source export and integration fixtures.

```bash
uv sync --extra dev
uv run python tools/verify.py --smartperfetto ../SmartPerfetto
```

Generated runtime indexes are sharded by Skill so agents load only the selected
workflow/query. See [architecture](docs/architecture.md),
[compatibility](docs/compatibility.md), and
[migration coverage](docs/migration-coverage.md).

## Releases and license

Tagged releases contain reproducible `.zip` and `.tar.gz` bundles plus
`SHA256SUMS`. Trace processor executables and trace fixtures are not bundled.
SmartPerfetto-derived work is AGPL-3.0-or-later; upstream Perfetto material
retains Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
