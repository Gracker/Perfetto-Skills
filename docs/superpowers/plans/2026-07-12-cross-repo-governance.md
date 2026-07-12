# Cross-Repository Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add aligned project-choice README tables and enforce a bidirectional SmartPerfetto/Perfetto-Skills impact decision before relevant commits or pushes.

**Architecture:** Each repository owns a small path classifier and mandatory Agent routing text. The classifier includes branch, staged, unstaged, and untracked paths and computes a change-set fingerprint. The AI records `required`, `not_required`, or `deferred` in commit/PR notes; it never guesses semantics. `required` validates a paired repository/ref and `deferred` requires a durable handoff.

**Tech Stack:** Markdown, Python 3.11 standard library, Node.js 24 ESM, Python `unittest`, SmartPerfetto Jest/project scripts.

## Global Constraints

- Preserve SmartPerfetto's unrelated `.gitignore` modification.
- Keep SmartPerfetto `AGENTS.md` and `CLAUDE.md` byte-for-byte synchronized.
- Do not make either installed product depend on the sibling checkout.
- A `required` decision must update the paired repository or report a durable blocked/deferred handoff.
- Generated Skill files are not edited in this plan.
- Use the exact current project-defined verification commands.

---

### Task 1: Add the bilingual three-project choice tables

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify in SmartPerfetto: `../SmartPerfetto/README.md`
- Modify in SmartPerfetto: `../SmartPerfetto/README.zh-CN.md`
- Test: `tests/unit/test_repository_contract.py`

**Interfaces:**
- Consumes: public URLs for SmartPerfetto, Perfetto Skills, official Perfetto Skill source, and official Perfetto AI documentation.
- Produces: the same three project rows in all four README surfaces.

- [ ] **Step 1: Add a failing README contract test**

Add to `tests/unit/test_repository_contract.py`:

```python
PROJECT_LINKS = {
    "https://github.com/Gracker/SmartPerfetto",
    "https://github.com/Gracker/Perfetto-Skills",
    "https://github.com/google/perfetto/tree/main/ai/skills/perfetto",
    "https://perfetto.dev/docs/getting-started/using-ai",
}

def test_readmes_offer_three_perfetto_project_choices(self) -> None:
    for name in ("README.md", "README.zh-CN.md"):
        text = (ROOT / name).read_text(encoding="utf-8")
        self.assertIn("SmartPerfetto", text)
        self.assertIn("Perfetto Skills", text)
        self.assertIn("Google", text)
        for link in PROJECT_LINKS:
            self.assertIn(link, text)
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `uv run python -m unittest tests.unit.test_repository_contract`

Expected: FAIL because the current public README lacks the complete four-link table.

- [ ] **Step 3: Add the aligned English and Chinese tables**

Place each table after the short introduction and before provider/install setup. Use columns equivalent to:

```markdown
| Project | Form | Best for | Main boundary | Choose it when |
|---|---|---|---|---|
| [SmartPerfetto](https://github.com/Gracker/SmartPerfetto) | Full Web UI, CLI, and backend | End-to-end interactive Android analysis | Managed runtime, reports, sessions, comparisons, providers | You want a complete product |
| [Perfetto Skills](https://github.com/Gracker/Perfetto-Skills) | Portable standard Agent Skill | Existing local coding agents | Deterministic local runner and broad evidence workflows | You want trace analysis inside Codex, Claude Code, or OpenCode |
| [Google official Perfetto Skill](https://github.com/google/perfetto/tree/main/ai/skills/perfetto) | Official upstream Skill bundle | Upstream-first recording and analysis | Official recording, memory, GPU, and PerfettoSQL guidance | You want the smallest upstream-maintained starting point |
```

Link the Google row or adjacent sentence to `https://perfetto.dev/docs/getting-started/using-ai`. Translate meaning, not product names, in the Chinese tables.

- [ ] **Step 4: Run the public contract test**

Run: `uv run python -m unittest tests.unit.test_repository_contract`

Expected: PASS.

- [ ] **Step 5: Verify the SmartPerfetto README rows directly**

Run:

```bash
for file in ../SmartPerfetto/README.md ../SmartPerfetto/README.zh-CN.md; do
  rg -q 'Gracker/SmartPerfetto' "$file"
  rg -q 'Gracker/Perfetto-Skills' "$file"
  rg -q 'google/perfetto/tree/main/ai/skills/perfetto' "$file"
  rg -q 'perfetto.dev/docs/getting-started/using-ai' "$file"
done
```

Expected: exit 0.

- [ ] **Step 6: Commit the public README changes**

```bash
git add README.md README.zh-CN.md tests/unit/test_repository_contract.py
git commit -m "docs: compare Perfetto analysis choices"
```

Do not commit SmartPerfetto files from the public repository.

---

### Task 2: Implement the Perfetto-Skills impact classifier

**Files:**
- Create: `tools/check_cross_repo_impact.py`
- Create: `tests/unit/test_cross_repo_impact.py`
- Modify: `AGENTS.md`
- Create: `docs/maintenance/upstream-sync.md`

**Interfaces:**
- Produces: `classify(repository: str, paths: list[str]) -> dict[str, object]` and a CLI accepting `--repository`, `--base`, repeated `--path`, `--decision`, `--reason`, and `--handoff`.
- Consumes: explicit paths or the union of merge-base-to-HEAD, staged,
  unstaged, and untracked paths. Dotfiles are preserved by removing only an
  exact leading `./`; unsafe `../` paths are rejected.

- [ ] **Step 1: Write failing classifier tests**

Create tests covering these invariants:

```python
def test_public_runtime_change_requires_review(self):
    result = impact.classify("perfetto-skills", [
        "skills/perfetto-performance-analysis/scripts/runtime/executor.py"
    ])
    self.assertTrue(result["review_required"])
    self.assertEqual(result["paired_repository"], "SmartPerfetto")

def test_public_readme_only_change_is_local(self):
    result = impact.classify("perfetto-skills", ["README.md"])
    self.assertFalse(result["review_required"])

def test_triggered_cli_requires_explicit_decision(self):
    self.assertEqual(impact.main([
        "--repository", "perfetto-skills",
        "--path", "src/sql/example.sql",
    ]), 2)

def test_deferred_requires_handoff(self):
    self.assertEqual(impact.main([
        "--repository", "perfetto-skills",
        "--path", "src/sql/example.sql",
        "--decision", "deferred",
    ]), 2)
```

- [ ] **Step 2: Run the tests and verify they fail**

Run: `uv run python -m unittest tests.unit.test_cross_repo_impact`

Expected: FAIL because the module does not exist.

- [ ] **Step 3: Implement path classification and decision validation**

Define immutable trigger prefixes for both repositories. The public set must include:

```python
PUBLIC_TRIGGERS = (
    "catalog/",
    "skills/perfetto-performance-analysis/",
    "src/",
    "upstreams/",
    "fixtures/",
    "tools/export_from_smartperfetto.py",
    "tools/compile_skill.py",
)
```

The result JSON contains `repository`, `paired_repository`, `review_required`,
`matched_paths`, `change_fingerprint`, paired repository/ref evidence, and
`decision`. Add tests for `.claude/...`, `../`, staged, unstaged, and untracked
paths. Validation rules:

- triggered change with no decision: exit 2;
- `not_required`: non-empty `--reason` required;
- `deferred`: non-empty `--reason` and `--handoff` required;
- `required`: non-empty `--reason` required;
- `required`: `--paired-path` or immutable `--paired-ref` is required and its
  repository identity/ref is validated;
- no trigger: decision defaults to `not_required` with reason `no paired-contract paths changed`.

- [ ] **Step 4: Run classifier tests**

Run: `uv run python -m unittest tests.unit.test_cross_repo_impact`

Expected: PASS.

- [ ] **Step 5: Add mandatory public Agent routing**

In `AGENTS.md`, add a short `Cross-repository impact` section that requires running:

```bash
uv run python tools/check_cross_repo_impact.py --repository perfetto-skills \
  --base "$(git merge-base HEAD origin/main)"
```

Route details to `docs/maintenance/upstream-sync.md`. The detailed document must list triggers, decision semantics, paired validation, and the rule that local overlays are reviewed rather than copied mechanically to SmartPerfetto.

- [ ] **Step 6: Add a rule-presence test**

Extend `tests/unit/test_repository_contract.py` to assert `AGENTS.md` contains `check_cross_repo_impact.py`, all three decision values, and `docs/maintenance/upstream-sync.md`.

- [ ] **Step 7: Run public unit tests**

Run:

```bash
uv run python -m unittest \
  tests.unit.test_cross_repo_impact \
  tests.unit.test_repository_contract
```

Expected: PASS.

- [ ] **Step 8: Commit the public governance changes**

```bash
git add AGENTS.md docs/maintenance/upstream-sync.md tools/check_cross_repo_impact.py \
  tests/unit/test_cross_repo_impact.py tests/unit/test_repository_contract.py
git commit -m "feat: require cross-repository impact review"
```

---

### Task 3: Add the SmartPerfetto side of the impact gate

**Files:**
- Modify in SmartPerfetto: `../SmartPerfetto/AGENTS.md`
- Modify in SmartPerfetto: `../SmartPerfetto/CLAUDE.md`
- Modify in SmartPerfetto: `../SmartPerfetto/.claude/rules/skills.md`
- Create in SmartPerfetto: `../SmartPerfetto/scripts/check-perfetto-skills-impact.mjs`
- Create in SmartPerfetto: `../SmartPerfetto/scripts/__tests__/check-perfetto-skills-impact.test.mjs`
- Modify in SmartPerfetto: `../SmartPerfetto/package.json`

**Interfaces:**
- Produces: a Node CLI with the same decision values and SmartPerfetto path triggers.
- Consumes: explicit paths or paths from the merge base returned by `git merge-base HEAD origin/main`.

- [ ] **Step 1: Write the failing Node classifier test**

Test at least:

```javascript
assert.equal(classify(['backend/skills/atomic/example.skill.yaml']).reviewRequired, true);
assert.equal(classify(['backend/src/services/skillEngine/skillExecutor.ts']).reviewRequired, true);
assert.equal(classify(['frontend/index.html']).reviewRequired, false);
assert.throws(() => validateDecision({ reviewRequired: true }, {}), /decision/);
```

- [ ] **Step 2: Run the Node test and verify it fails**

Run from SmartPerfetto: `node --test scripts/__tests__/check-perfetto-skills-impact.test.mjs`

Expected: FAIL because the CLI module does not exist.

- [ ] **Step 3: Implement the SmartPerfetto classifier**

Trigger at least:

```javascript
const TRIGGERS = [
  'backend/skills/',
  'backend/strategies/',
  'backend/src/services/skillEngine/',
  'backend/src/services/evidence',
  'backend/src/services/deterministicClaim',
  'backend/src/services/processIdentity',
  'backend/data/perfetto',
  'scripts/trace-processor-pin.env',
  '.claude/rules/skills.md',
];
```

Match the public CLI's decision validation and JSON fields. Add package command:

```json
"check:perfetto-skills-impact": "node scripts/check-perfetto-skills-impact.mjs"
```

- [ ] **Step 4: Update SmartPerfetto Agent rules**

Add the mandatory check to `AGENTS.md`, copy it exactly to `CLAUDE.md`, and add detailed triggers and paired validation to `.claude/rules/skills.md`. Preserve the existing public-export rules.

- [ ] **Step 5: Run SmartPerfetto focused validation**

Run:

```bash
node --test scripts/__tests__/check-perfetto-skills-impact.test.mjs
npm run check:perfetto-skills-impact -- --path backend/skills/public-export.yaml \
  --decision not_required --reason "governance-only smoke"
cmp -s AGENTS.md CLAUDE.md
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 6: Commit SmartPerfetto README and governance changes**

From SmartPerfetto:

```bash
git add README.md README.zh-CN.md AGENTS.md CLAUDE.md .claude/rules/skills.md \
  scripts/check-perfetto-skills-impact.mjs \
  scripts/__tests__/check-perfetto-skills-impact.test.mjs package.json
git commit -m "docs(skills): require public sync impact review"
```

Do not stage `.gitignore`.

---

### Task 4: Validate and independently review governance

**Files:**
- Verify only; modify findings only if confirmed.

**Interfaces:**
- Consumes: Tasks 1-3 commits.
- Produces: evidence that all Agent surfaces and README links agree.

- [ ] **Step 1: Run the Perfetto-Skills complete gate**

Run: `uv run python tools/verify.py --smartperfetto ../SmartPerfetto`

Expected: all tests, Agent Skill validation, export check, and catalog validation pass.

- [ ] **Step 2: Run the SmartPerfetto project gate**

Run from SmartPerfetto: `npm run verify:pr`

Expected: exit 0 using the repository-defined PR gate.

- [ ] **Step 3: Request an independent read-only review**

The reviewer checks README accuracy, rule symmetry, decision enforcement, unrelated `.gitignore` preservation, and absence of runtime coupling. Reviewers do not edit files.

- [ ] **Step 4: Fix confirmed findings and rerun affected gates**

Run the smallest focused tests first, then repeat both complete gates if behavior or rules change.

- [ ] **Step 5: Record impact decisions**

Run each repository's classifier against the full worktree with decision
`required`, paired repository/ref evidence, and a reason referring to the paired
commit hash. Record each JSON fingerprint and paired ref in the commit/PR notes.
Expected: both exit 0.
