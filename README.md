# Perfetto Skills

Portable Agent Skills for evidence-driven Android, Linux, and Chromium Perfetto
performance analysis.

This project extracts SmartPerfetto's analysis methodology, deterministic SQL
evidence catalog, and rendering-pipeline knowledge into the open Agent Skills
format. It is designed for compatible agents with filesystem and terminal
access and does not require the SmartPerfetto backend, web UI, provider
runtime, or MCP server.

## Status

The public repository is being built from the current SmartPerfetto source of
truth. The first release is complete only after standards validation,
full-source migration coverage, real-trace tests, and fresh-clone verification
all pass.

## Development

Requirements:

- Python 3.11+
- `uv`
- a sibling SmartPerfetto checkout for export and integration verification

```bash
uv sync --extra dev
uv run python tools/verify.py --smartperfetto ../SmartPerfetto
```

See [the architecture design](docs/superpowers/specs/2026-07-11-perfetto-skills-design.md)
and [implementation plan](docs/superpowers/plans/2026-07-11-perfetto-skills-implementation.md).

## License

SmartPerfetto-derived work is licensed under AGPL-3.0-or-later. Upstream
Perfetto material retains its original Apache-2.0 notices. See [LICENSE](LICENSE)
and [NOTICE](NOTICE).

