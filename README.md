# Perfetto Skills

Portable Agent Skills for evidence-driven Android, Linux, and Chromium Perfetto
performance analysis.

This project extracts SmartPerfetto's analysis methodology, deterministic SQL
evidence catalog, and rendering-pipeline knowledge into the open Agent Skills
format. It is designed for compatible agents with filesystem and terminal
access and does not require the SmartPerfetto backend, web UI, provider
runtime, or MCP server.

## Install

Clone the repository, then install the canonical Skill tree for your client:

```bash
python3 tools/install.py --client codex
python3 tools/install.py --client claude-code
python3 tools/install.py --client opencode
```

Use `--destination /absolute/skills/directory` for another Agent Skills client.
Existing installs are never replaced unless `--force` is explicit. The Skill
contains no bundled executable: on first use, point it at a compatible
`trace_processor_shell` or let the checksum-pinned bootstrap script install one
into the local cache.

After restarting or refreshing your client, ask it to use
`$perfetto-performance-analysis` on a local `.pftrace` file.

## Contents

- One standard `perfetto-performance-analysis` Agent Skill and client-optional
  OpenAI metadata.
- 14 standalone analysis workflows.
- 230 generated SmartPerfetto Skill references and 635 extracted SQL queries.
- 50 portable strategy/knowledge references and 32 rendering-pipeline docs.
- A checksum-pinned, cross-platform trace-processor bootstrap and query runtime.
- Safe scalar/result parameter binding and file-based multi-trace comparison,
  with no dependency on SmartPerfetto session or snapshot services.

## Development

Requirements:

- Python 3.11+
- `uv`
- a sibling SmartPerfetto checkout for export and integration verification

```bash
uv sync --extra dev
uv run python tools/verify.py --smartperfetto ../SmartPerfetto
```

## Releases

Tagged releases contain reproducible `.zip` and `.tar.gz` bundles plus
`SHA256SUMS`. Each archive has one installable
`perfetto-performance-analysis/` directory, `LICENSE`, `NOTICE`, and
`PROVENANCE.json`; trace processor executables and trace fixtures are never
bundled. Verify checksums before extracting, then copy the Skill directory to
your client's Skill root.

See [the architecture design](docs/superpowers/specs/2026-07-11-perfetto-skills-design.md)
and [implementation plan](docs/superpowers/plans/2026-07-11-perfetto-skills-implementation.md).
The maintained public contract is documented in [architecture](docs/architecture.md),
[compatibility](docs/compatibility.md), and generated
[migration coverage](docs/migration-coverage.md).

## License

SmartPerfetto-derived work is licensed under AGPL-3.0-or-later. Upstream
Perfetto material retains its original Apache-2.0 notices. See [LICENSE](LICENSE)
and [NOTICE](NOTICE).
