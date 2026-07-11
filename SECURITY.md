# Security Policy

## Supported versions

Security fixes are applied to the latest release and the `main` branch.

## Reporting a vulnerability

Use GitHub private vulnerability reporting for `Gracker/Perfetto-Skills`. Do
not open a public issue for credential exposure, unsafe download behavior,
archive traversal, command injection, or other vulnerabilities that could put
users at risk.

Reports should include affected paths, reproduction steps, impact, and the
smallest safe diagnostic artifacts. Do not include proprietary trace contents
or credentials.

## Trust boundaries

- Trace files and generated query results are untrusted input.
- Runtime commands never invoke a shell with user-provided values.
- Downloaded trace processor binaries must match the repository lock file.
- Installation refuses to overwrite existing Skills unless explicitly forced.
- CI and issue logs must not publish trace contents.

## Release integrity

Release workflows pin third-party actions by full commit SHA, verify the public
export against the catalog-pinned SmartPerfetto commit, run real-trace tests,
and build byte-for-byte reproducible archives. `SHA256SUMS` covers every release
archive, while `PROVENANCE.json` records the source catalog and SmartPerfetto
commit. Release bundles never contain `trace_processor_shell`; the runtime
bootstrap verifies that executable separately against
`references/trace-processor-lock.json`.
