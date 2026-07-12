# Compatibility

## Required capabilities

- Python 3.11 or newer.
- Local filesystem access to the Skill and trace.
- Permission to execute a local process.
- A compatible Perfetto `trace_processor_shell`.

The Skill is client-independent. The installer has defaults for Codex
(`~/.agents/skills`), Claude Code (`~/.claude/skills`), and OpenCode
(`~/.config/opencode/skills`), plus `--destination` for other standard Agent Skills
clients. `agents/openai.yaml` is optional UI metadata and does not add a runtime
dependency.

Cloud-only agents without filesystem or terminal access can read the
methodology but cannot probe a trace or execute SQL.

Generated SQL retains source placeholders. Execute it through
`perfetto_query.py`: use `--param` for JSON scalar values or arrays (arrays
become SQL literal lists for `IN (...)`), `--module` for declared stdlib
prerequisites, and `--result` for a non-empty JSON row array from a prior step.
Dotted fields and numeric indexes resolve pipeline expressions such as
`${step.data[0].upid}`. Direct text substitution is unsupported. Query output
is bounded to 16 MiB per stream unless an explicit reviewed override is
supplied.

## Trace processor

The current lock pins Perfetto `v57.2` and publishes a SHA-256 for each supported
artifact:

| Host | Lock key | Bootstrap support |
|---|---|---|
| macOS Apple Silicon | `mac-arm64` | Yes |
| macOS Intel | `mac-amd64` | Yes |
| Linux x86-64 | `linux-amd64` | Yes |
| Linux ARM64 | `linux-arm64` | Yes |
| Windows x86-64 | `windows-amd64` | Yes |

An explicit `--trace-processor` wins, followed by
`PERFETTO_TRACE_PROCESSOR`, `PATH`, and the verified cache. Before a complete
Skill or manifest query runs, `perfetto_doctor.py` checks the binary commit, RPC
API, platform, and SHA-256. A mismatch is rejected by default; the deliberately
verbose `--allow-unsupported-processor` flag is the only bypass and the
unsupported identity remains attached to evidence.

## Trace and platform variation

Android version, kernel, framework, browser, engine, OEM, trace configuration,
and permissions determine which signals exist. FrameTimeline, GPU, heap graph,
Binder, blocked-function, power rail, thermal, and vendor evidence are all
optional. Workflows probe first and retain one of five states: `unsupported`,
`not_recorded`, `recorded_empty`, `recorded_populated`, or `unknown`. Schema
presence alone never proves that a signal was recorded, and missing evidence is
never converted into zero.

Every exported Skill, step, and query has an API 28–37 capability matrix.
Those entries are adapter hints, not claims that Android version alone implies
a schema or recording configuration. The committed fixture set exercises APIs
24, 31, 32, 34, 35, and 36 where suitable traces exist. No API 37 trace is
currently committed, so API 37 remains capability-gated/unknown rather than
being reported as verified.

Rendering thread/slice names are version and vendor signals rather than stable
APIs. Pipeline detection retains competing candidates and falls back to generic
producer/compositor evidence when confidence is low.

## Licensing

SmartPerfetto-derived code and methodology are AGPL-3.0-or-later. Upstream
Perfetto material retains its Apache-2.0 notices. See the repository `LICENSE`
and `NOTICE` before redistribution.
