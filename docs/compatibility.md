# Compatibility

## Required capabilities

- Python 3.11 or newer.
- Local filesystem access to the Skill and trace.
- Permission to execute a local process.
- A compatible Perfetto `trace_processor_shell`.

The Skill is client-independent. The installer has defaults for Codex
(`~/.agents/skills`), Claude Code (`~/.claude/skills`), and OpenCode
(`~/.opencode/skills`), plus `--destination` for other standard Agent Skills
clients. `agents/openai.yaml` is optional UI metadata and does not add a runtime
dependency.

Cloud-only agents without filesystem or terminal access can read the
methodology but cannot probe a trace or execute SQL.

## Trace processor

The current lock pins Perfetto `v57.1` and publishes a SHA-256 for each supported
artifact:

| Host | Lock key | Bootstrap support |
|---|---|---|
| macOS Apple Silicon | `mac-arm64` | Yes |
| macOS Intel | `mac-amd64` | Yes |
| Linux x86-64 | `linux-amd64` | Yes |
| Linux ARM64 | `linux-arm64` | Yes |
| Windows x86-64 | `windows-amd64` | Yes |

An explicit `--trace-processor` wins, followed by
`PERFETTO_TRACE_PROCESSOR`, `PATH`, and the verified cache. A different
trace-processor version may change available tables, stdlib modules, or query
semantics; record the executable version with evidence.

## Trace and platform variation

Android version, kernel, framework, browser, engine, OEM, trace configuration,
and permissions determine which signals exist. FrameTimeline, GPU, heap graph,
Binder, blocked-function, power rail, thermal, and vendor evidence are all
optional. Workflows always probe first and report `missing_evidence` instead of
converting unavailable data into zero.

Rendering thread/slice names are version and vendor signals rather than stable
APIs. Pipeline detection retains competing candidates and falls back to generic
producer/compositor evidence when confidence is low.

## Licensing

SmartPerfetto-derived code and methodology are AGPL-3.0-or-later. Upstream
Perfetto material retains its Apache-2.0 notices. See the repository `LICENSE`
and `NOTICE` before redistribution.
