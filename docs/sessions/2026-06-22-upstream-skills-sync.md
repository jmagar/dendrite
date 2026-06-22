# Session: upstream-skills vendoring + sync tool

- **Date:** 2026-06-22
- **Branch:** `feat/upstream-skills-sync`
- **HEAD:** `242662b` (at time of writing)
- **Worktree:** `/home/jmagar/workspace/dendrite/.worktrees/upstream-skills-sync`
- **PR:** https://github.com/jmagar/dendrite/pull/4 (`feat/upstream-skills-sync` → `main`)
- **Base:** merged `origin/main` in (branch had diverged 6 commits)

## What shipped

A new `upstream-skills` marketplace plugin that vendors 11 agent skills verbatim
from upstream repos, plus a `sync-upstream-skills` tool that onboards a skill
from a single GitHub URL and detects/applies upstream drift.

- **Plugin** `plugins/upstream-skills/` — 11 skills (`gog`, `acpx`, `meme-maker`,
  `agent-transcript`, `autoreview`, `handoff`, `session-viewer`, `openai-docs`,
  `define-goal`, `chatgpt-apps`, `yeet`) from `openclaw/{gogcli,acpx,openclaw,
  agent-skills}` and `openai/skills`. Each skill = verbatim upstream folder + a
  generated `agents/openai.yaml`.
- **Tool** `plugins/scripts/sync-upstream-skills` (stdlib-only): `add <url>`,
  `check`, `apply [names…|--all]`. Drift = content hash over the whole skill
  subtree (catches references/scripts/added/removed files).
- **Data contract** `plugins/schemas/upstream-sources.schema.json`, validated via
  `validate-plugin-schemas` (in `check-all`).
- **Tests** `plugins/scripts/tests/test_sync_upstream_skills.py` — 46 unittest
  cases (network seams monkeypatched, offline), wired into `check-all`.

## Design + plan artifacts

- `docs/superpowers/specs/2026-06-21-upstream-skills-sync-design.md`
- `docs/superpowers/plans/2026-06-22-upstream-skills-sync.md`

## Deduplication

`origin/main` had previously vendored the same `gog` skill into `vibin`
(commit `9164122`). Resolved by making `upstream-skills` the single sync-managed
home for `gog` and removing `vibin/skills/gog` (git shows it as a rename).

## Verification

- `python3 plugins/scripts/tests/test_sync_upstream_skills.py` → 46 passed
- `plugins/scripts/check-all` → exit 0
- CI on PR #4: `validate` pass, GitGuardian pass, CodeRabbit review completed,
  cubic skipped, Codex over quota.

## Review waves run

- pr-review-toolkit: code-reviewer, silent-failure-hunter, pr-test-analyzer,
  code-simplifier (impl + tests), comment-analyzer, plus an adversarial
  re-verification of the security fix.
- **Findings addressed:** path-traversal guard in tarball extraction (security),
  `_gh()` helper surfacing stderr / missing-gh, JSON-shape guards in
  `resolve_tip_sha`, corrupt-manifest + missing-`SKILL.md` errors, atomic
  manifest write, per-entry error handling in `check`, orphan cleanup on failed
  `add`, rationale comments, +18 tests.
- **Deliberately declined:** the `SusTestCase` base-class mixin and `make_entry`
  factory test refactors — the simplifier flagged the mixin as risky
  (mid-test reassignment vs. patch-revert), and existing fixtures are already
  correct and readable; risk outweighed cosmetic gain.

## PR comments resolved

Zero unresolved review threads. External AI reviewers were rate-limited
(CodeRabbit summary only), over quota (Codex), or skipped (cubic); no actionable
inline comments were posted.

## Remaining risks / follow-ups

- `check-no-mcp-drift` is skipped off the `marketplace-no-mcp` branch;
  `upstream-skills` has no MCP server so the no-MCP transform is identity. After
  merge, the scheduled sync keeps `marketplace-no-mcp` current.
- A scheduled `sync-upstream-skills check` GitHub workflow remains an optional
  future addition (out of scope per the spec).

## Note

`vibin:save-to-md` was not invoked directly because it captures the coordinator
session's cwd/git context rather than this feature worktree's; this artifact was
authored manually with accurate worktree/PR context per that skill's documented
fallback.
