# Project-owned trace fixtures

`manifest.json` is the source of truth for Perfetto-Skills' independently owned
real-trace test matrix. The small Apache-2.0 API 32 warm-start trace under
`smoke/` is committed for offline verification. Larger traces are distributed
only in the immutable `fixtures-v2` GitHub Release asset and are never included
in the installable Skill archive.

Every release-blocking trace has immutable provenance, redistribution approval,
privacy-scan evidence, platform/capture metadata, a SHA-256, and stable semantic
assertion IDs. `coverage_status.pending_real_trace` is intentionally explicit:
those scenarios are not claimed as covered until a reviewed real trace and
assertion are added in a later immutable fixture pack.

Build and download commands are documented in
[`docs/maintenance/upstream-sync.md`](../docs/maintenance/upstream-sync.md).
