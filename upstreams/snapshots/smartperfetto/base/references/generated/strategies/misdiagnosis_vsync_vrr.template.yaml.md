GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/phase_hint_templates/misdiagnosis_vsync_vrr.template.yaml
Source SHA-256: 3be98f9aee8cdcc3fb82c38e8f9e87e7cf3f1e802a52394bd191343271b23125
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

# Misdiagnosis_Vsync_Vrr Template Yaml

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

```yaml
# SPDX-License-Identifier: AGPL-3.0-or-later
# Phase-hint template for failureCategory `misdiagnosis_vsync_vrr`.
#
# The strategy patcher (proposeStrategyPatch.ts) renders one of these for
# every active failure-category. The rendered YAML is appended to the
# scene's `.strategy.md` frontmatter under `phase_hints` — the LLM never
# writes YAML directly.
#
# Substitution variables (filled by the renderer):
#   {{categoryId}}             — kebab-case form of failureCategoryEnum
#   {{patchFingerprint}}       — sha256-truncated stable id
#   {{appliedAt}}              — unix ms timestamp
#   {{evidenceSummary}}        — one paragraph from the review agent
#   {{candidateKeywords}}      — string[] of keyword tokens
#   {{candidateConstraints}}   — single-paragraph constraint text
#   {{candidateCriticalTools}} — string[] of tool/skill IDs
#
# Renderer rules:
#   1. Keywords are sorted ascending so cosmetic reordering doesn't change
#      the patch fingerprint.
#   2. critical_tools items are validated against the active tool/skill
#      registry — unknown IDs cause the renderer to refuse the patch.
#   3. critical: defaults to false. Auto-generated patches never override
#      a hand-written critical hint.
#   4. The whole entry is tagged `auto_generated: true` so a human review
#      can find auto patches in the file.

id: "auto_{{categoryId}}_{{patchFingerprint}}"
keywords: {{candidateKeywords}}
constraints: |
  {{candidateConstraints}}
critical_tools: {{candidateCriticalTools}}
critical: false
auto_generated: true
applied_at: {{appliedAt}}
evidence: |
  {{evidenceSummary}}
```
