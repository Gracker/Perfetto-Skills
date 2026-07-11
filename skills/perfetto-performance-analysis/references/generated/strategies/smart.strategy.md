GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/smart.strategy.md
Source SHA-256: 85a09187e5ab929984ba5b0897d330595a777ea27c6c101c1f29661a95181870
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

# Smart Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

# Smart Analysis Contract

This strategy is intentionally contract-only. It must not be injected as a
normal scene strategy and must not participate in scene classification.

Smart Analysis Mode combines Scene Story detection with profile-specific
deep-dive routes, then projects the resulting scene report into a readable chat
summary and the standard HTML report chain.
