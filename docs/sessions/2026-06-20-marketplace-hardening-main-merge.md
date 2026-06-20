---
date: 2026-06-20 18:26:02 EDT
repo: git@github.com:jmagar/dendrite.git
branch: main
head: 3bab090209566f4f47bc904ed3a3f849bfee145c
working directory: /home/jmagar/workspace/dendrite
worktree: /home/jmagar/workspace/dendrite
---

# Marketplace hardening and main merge

## User Request

Continue tightening, hardening, and optimizing the Dendrite marketplace work, then commit and push any unstaged work, merge everything back into `main`, leave the protected `marketplace-no-mcp` branch intact, and save the session to markdown.

## Session Overview

Restored `main` as the full/default marketplace, documented `marketplace-no-mcp` as Jacob's gateway-oriented derived variant, hardened marketplace validation and no-MCP drift automation, merged the feature branch back into `main`, pushed `main`, verified GitHub Actions, fast-forwarded the local no-MCP worktree, and cleaned up merged feature branches.

## Sequence of Events

1. Repaired the marketplace model so `main` remains the normal full marketplace and `marketplace-no-mcp` remains a deterministic no-MCP derivative.
2. Added missing plugin documentation, new operational docs, restored full-marketplace MCP snippets, and regenerated marketplace inventories.
3. Hardened checks so plugin README/CHANGELOG placeholders fail, Gemini manifests stay generated, no-MCP marketplace names are enforced, and skill-body config references are validated.
4. Optimized the no-MCP transform and sync workflow so `apply-no-mcp-marketplace` regenerates derived Gemini manifests, README inventory, and generated docs.
5. Merged `codex/docs-marketplace-repair` into `main`, pushed `main`, watched push-triggered workflows complete successfully, and left `marketplace-no-mcp` protected.
6. Removed merged local/remote feature branches after proving they were ancestors of `main`.

## Key Findings

- `main` had drifted toward the no-MCP install model; the marketplace manifests now use `dendrite` and the no-MCP-only refs are removed from `main`.
- Gemini manifest generation already supported `.mcp.json`; the initial check failure was JSON order/staleness, resolved by regenerating manifests from source.
- `check-marketplace-sync` did not scan `skills/` for config references; it now matches the config-doc generator's coverage.
- The no-MCP transform needed to be self-contained so `apply-no-mcp-marketplace && check-all` is valid.
- `origin/claude/available-skills-w6p7jm` is not merged into `main`; it was left untouched.

## Technical Decisions

- Kept `main` as the full marketplace for normal users because most users do not already have Jacob's MCP servers registered in a gateway.
- Kept `marketplace-no-mcp` as a long-lived protected release variant and updated only its generated state through the sync workflow.
- Made `plugins/scripts/apply-no-mcp-marketplace` regenerate derived artifacts to reduce ordering mistakes in local and CI workflows.
- Added docs checks to `plugins/scripts/check-all` so empty README/CHANGELOG placeholders cannot silently reappear.
- Deleted only branches proven merged into `main`; left the unrelated unmerged remote branch in place.

## Files Changed

| status | path | previous path | purpose | evidence |
|---|---|---|---|---|
| modified | `.agents/plugins/marketplace.json` |  | Restore full `dendrite` marketplace metadata and remove no-MCP source refs from `main`. | `git show --name-status 3b1d56f` |
| modified | `.claude-plugin/marketplace.json` |  | Restore full `dendrite` marketplace metadata and remove no-MCP source refs from `main`. | `git show --name-status 3b1d56f` |
| modified | `.github/workflows/sync-marketplace-no-mcp.yml` |  | Remove redundant README generation now handled by the transform. | `git show --name-status eb1eb96` |
| modified | `CHANGELOG.md` |  | Record marketplace docs, validation, and no-MCP hardening changes. | `git show --name-status 3b1d56f` |
| modified | `CLAUDE.md` |  | Clarify full/default vs no-MCP branch rules and current checks. | `git show --name-status 3b1d56f`, `eb1eb96` |
| modified | `README.md` |  | Document full/default marketplace behavior, no-MCP transform behavior, and refreshed inventory. | `git show --name-status 3b1d56f`, `eb1eb96` |
| modified | `docs/configuration-matrix.md` |  | Regenerated config matrix with broader consumer coverage. | `plugins/scripts/generate-docs` |
| created | `docs/configuration.md` |  | Add configuration runbook. | `git show --name-status 3b1d56f` |
| created | `docs/installation.md` |  | Add Claude, Codex, and Gemini install commands. | `git show --name-status 3b1d56f` |
| created | `docs/marketplace-operations.md` |  | Add marketplace add/update/remove runbook. | `git show --name-status 3b1d56f` |
| modified | `docs/marketplace-sources.md` |  | Regenerate marketplace source inventory. | `plugins/scripts/generate-docs` |
| modified | `docs/no-mcp-variant.md` |  | Document expected no-MCP refs and branch handling. | `plugins/scripts/generate-docs` |
| created | `docs/plugin-documentation-standard.md` |  | Define useful README/CHANGELOG expectations. | `git show --name-status 3b1d56f` |
| modified | `docs/plugin-matrix.md` |  | Regenerate plugin matrix with doc status. | `plugins/scripts/generate-docs` |
| created | `docs/release-and-changelog.md` |  | Add release/changelog runbook. | `git show --name-status 3b1d56f` |
| created | `plugins/acp/.mcp.json` |  | Restore full-marketplace MCP config placeholder. | `git show --name-status 3b1d56f` |
| created | `plugins/agent-os/.mcp.json` |  | Restore Windows-MCP registration for full marketplace. | `git show --name-status 3b1d56f` |
| modified | `plugins/agent-os/gemini-extension.json` |  | Regenerate Gemini MCP server entry from `.mcp.json`. | `plugins/scripts/generate-gemini-extensions` |
| modified | `plugins/bytestash/CHANGELOG.md` |  | Fill useful plugin changelog content. | `git show --name-status 3b1d56f` |
| modified | `plugins/bytestash/README.md` |  | Fill useful plugin README content. | `git show --name-status 3b1d56f` |
| created | `plugins/dozzle/.mcp.json` |  | Restore Dozzle MCP registration for full marketplace. | `git show --name-status 3b1d56f` |
| modified | `plugins/dozzle/gemini-extension.json` |  | Regenerate Gemini MCP server entry from `.mcp.json`. | `plugins/scripts/generate-gemini-extensions` |
| modified | `plugins/immich/CHANGELOG.md` |  | Fill useful plugin changelog content. | `git show --name-status 3b1d56f` |
| modified | `plugins/immich/README.md` |  | Fill useful plugin README content. | `git show --name-status 3b1d56f` |
| modified | `plugins/linkding/CHANGELOG.md` |  | Fill useful plugin changelog content. | `git show --name-status 3b1d56f` |
| modified | `plugins/linkding/README.md` |  | Fill useful plugin README content. | `git show --name-status 3b1d56f` |
| modified | `plugins/loggifly/CHANGELOG.md` |  | Fill useful plugin changelog content. | `git show --name-status 3b1d56f` |
| modified | `plugins/loggifly/README.md` |  | Fill useful plugin README content. | `git show --name-status 3b1d56f` |
| modified | `plugins/memos/CHANGELOG.md` |  | Fill useful plugin changelog content. | `git show --name-status 3b1d56f` |
| modified | `plugins/memos/README.md` |  | Fill useful plugin README content. | `git show --name-status 3b1d56f` |
| modified | `plugins/notebooklm/CHANGELOG.md` |  | Fill useful plugin changelog content. | `git show --name-status 3b1d56f` |
| modified | `plugins/notebooklm/README.md` |  | Fill useful plugin README content. | `git show --name-status 3b1d56f` |
| modified | `plugins/radicale/CHANGELOG.md` |  | Fill useful plugin changelog content. | `git show --name-status 3b1d56f` |
| modified | `plugins/radicale/README.md` |  | Fill useful plugin README content. | `git show --name-status 3b1d56f` |
| modified | `plugins/scripts/apply-no-mcp-marketplace` |  | Set no-MCP marketplace name and regenerate derived artifacts. | `git show --name-status 3b1d56f` |
| modified | `plugins/scripts/check-all` |  | Include plugin documentation checks. | `git show --name-status 3b1d56f` |
| modified | `plugins/scripts/check-marketplace-sync` |  | Include skill files in config reference scanning. | `git show --name-status eb1eb96` |
| modified | `plugins/scripts/check-no-mcp-drift` |  | Enforce no-MCP marketplace name and remove duplicate generation. | `git show --name-status 3b1d56f`, `eb1eb96` |
| created | `plugins/scripts/check-plugin-docs` |  | Fail empty plugin README/CHANGELOG placeholders. | `git show --name-status 3b1d56f` |
| modified | `plugins/scripts/generate-docs` |  | Add doc status, skill-body config consumers, and expected no-MCP selector docs. | `git show --name-status 3b1d56f` |
| created | `plugins/swag/.mcp.json` |  | Restore SWAG MCP registrations for full marketplace. | `git show --name-status 3b1d56f` |
| modified | `plugins/swag/gemini-extension.json` |  | Regenerate Gemini MCP server entries from `.mcp.json`. | `plugins/scripts/generate-gemini-extensions` |
| created | `plugins/vibin/.mcp.json` |  | Restore full-marketplace MCP config placeholder. | `git show --name-status 3b1d56f` |
| created | `plugins/zsnoop-mcp/.mcp.json` |  | Restore zsnoop MCP registration for full marketplace. | `git show --name-status 3b1d56f` |
| modified | `plugins/zsnoop-mcp/gemini-extension.json` |  | Regenerate Gemini MCP server entry from `.mcp.json`. | `plugins/scripts/generate-gemini-extensions` |

## Beads Activity

No bead activity observed. `bd list --all --sort updated --reverse --limit 50 --json` failed with `Error: no beads database found`, so no tracker state was changed.

## Repository Maintenance

### Plans

No plan files were found under `docs/plans/`; no completed plans were moved.

### Beads

No beads database was present in this repository, so bead updates were skipped and documented.

### Worktrees and branches

- Main worktree is clean on `main` at `3bab090`.
- Protected worktree `/home/jmagar/workspace/_no_mcp_worktrees/dendrite` remains on `marketplace-no-mcp` and was fast-forwarded to `e3af078`.
- Removed stale worktree `/home/jmagar/workspace/dendrite/.worktrees/fix-skill-frontmatter` after proving `codex/fix-skill-frontmatter` was merged into `main`.
- Deleted merged local and remote branches `codex/docs-marketplace-repair`, `codex/fix-skill-frontmatter`, `codex/dendrite-gemini-skill-marketplace`, and `codex/no-mcp-drift-hardening`.
- Left `origin/claude/available-skills-w6p7jm` alone because `git merge-base --is-ancestor origin/claude/available-skills-w6p7jm main` returned nonzero.

### Stale docs

Updated `README.md`, `CLAUDE.md`, generated docs, and new runbooks so the full/default marketplace and no-MCP derived branch behavior are consistent with the implementation.

## Tools and Skills Used

- **Skills.** Used `superpowers:finishing-a-development-branch` for merge closeout and `vibin:save-to-md` for this session artifact.
- **MCP tools.** Used Lumen semantic search for initial code discovery after it became available.
- **Shell and Git.** Used git status, merge, push, branch cleanup, worktree inspection, and GitHub CLI workflow monitoring.
- **Validation scripts.** Used Dendrite scripts for marketplace checks, no-MCP transform checks, install smoke tests, and generated-doc checks.
- **External CLIs.** Used `gh` for workflow status and `bd` for tracker discovery; `bd` reported no database.

## Commands Executed

| command | result |
|---|---|
| `plugins/scripts/check-all` | Passed before merge, after merge, and in temp no-MCP transform checks. |
| `plugins/scripts/smoke-marketplace-install` | Passed Claude, Codex, and Gemini install smoke tests. |
| `plugins/scripts/apply-no-mcp-marketplace` in temp copies | Produced `dendrite-no-mcp` manifests with no local `.mcp.json` files. |
| `git checkout main && git pull --ff-only && git merge --no-ff codex/docs-marketplace-repair` | Merged feature branch into `main` as `3bab090`. |
| `git push origin main` | Pushed `main` from `90d7738` to `3bab090`. |
| `gh run watch 27885677792` | `Validate marketplaces` completed successfully. |
| `gh run watch 27885677775` | `Sync marketplace-no-mcp` had already completed successfully. |
| `git -C /home/jmagar/workspace/_no_mcp_worktrees/dendrite pull --ff-only` | Fast-forwarded protected no-MCP worktree to `e3af078`. |
| `git worktree remove ...fix-skill-frontmatter && git branch -d ... && git push origin --delete ...` | Removed merged feature worktree and deleted merged local/remote branches. |

## Errors Encountered

- A disposable no-MCP copy initially lacked `.git`, causing `check-no-mcp-drift` to fail when it asked Git for the current branch. The check was rerun in a disposable initialized repository.
- Gemini extension check initially reported restored MCP-backed manifests as stale because generator output order differed from hand-restored JSON. Regenerating manifests resolved it.
- `bd list` failed because this repository has no beads database; no bead state was changed.

## Behavior Changes (Before/After)

| area | before | after |
|---|---|---|
| Marketplace default | `main` contained no-MCP naming/refs from the alternate install model. | `main` publishes the full/default `dendrite` marketplace for normal users. |
| No-MCP variant | Depended on remembering extra generation steps. | `apply-no-mcp-marketplace` performs the deterministic no-MCP rewrite and regenerates derived artifacts. |
| Plugin docs | Empty README/CHANGELOG placeholders could pass. | `check-plugin-docs` fails placeholders below the minimum useful-content threshold. |
| Config drift | Skill-body config refs were documented but not checked by sync validation. | Skill-body config refs are included in `check-marketplace-sync`. |
| Branch state | Several merged feature branches and one stale feature worktree remained. | Merged feature branches/worktree were removed; protected no-MCP worktree remains. |

## Verification Evidence

| command | expected | actual | status |
|---|---|---|---|
| `plugins/scripts/check-all` | Full marketplace manifests and generated docs pass. | Passed. | pass |
| `plugins/scripts/smoke-marketplace-install` | Claude, Codex, and Gemini smoke installs pass. | Passed for marketplace `dendrite`; Codex listed 76 plugins. | pass |
| temp no-MCP transform + `plugins/scripts/check-all` | Transformed manifests are `dendrite-no-mcp` and no `.mcp.json` files remain. | Passed; `mcp_files=` empty. | pass |
| `git push origin main` | Push succeeds and pre-push checks pass. | Pushed `main` to `3bab090`; pre-push checks passed. | pass |
| `gh run watch 27885677792` | Validate marketplaces workflow succeeds. | Completed success in 1m7s. | pass |
| `gh run watch 27885677775` | Sync marketplace-no-mcp workflow succeeds. | Completed success. | pass |
| branch/worktree audit | Only `main` and protected `marketplace-no-mcp` remain locally. | Local branches: `main`, `marketplace-no-mcp`; worktrees: main and no-MCP. | pass |

## Risks and Rollback

- The no-MCP sync workflow will continue to update `marketplace-no-mcp`; rollback by reverting `3bab090` on `main` and allowing the sync workflow to regenerate the alternate branch.
- The deleted feature branches were proven merged into `main`; their commits remain reachable through `main` history.
- The unmerged remote `origin/claude/available-skills-w6p7jm` remains available because it was not proven safe to delete.

## Decisions Not Taken

- Did not merge or delete `marketplace-no-mcp`; it is a protected long-lived variant.
- Did not delete `origin/claude/available-skills-w6p7jm` because it is not an ancestor of `main`.
- Did not create or update beads because no beads database exists in this repo.

## References

- GitHub Actions runs: `27885677792` (`Validate marketplaces`) and `27885677775` (`Sync marketplace-no-mcp`).
- Commits: `3b1d56f`, `eb1eb96`, merge commit `3bab090`, no-MCP sync commit `e3af078`.

## Open Questions

- Whether `origin/claude/available-skills-w6p7jm` should remain open, be reviewed, or be merged later.

## Next Steps

- Use `main` for the full/default marketplace.
- Use `marketplace-no-mcp` only as the gateway-oriented no-MCP variant.
- If more marketplace changes land, run `plugins/scripts/check-all`, `plugins/scripts/smoke-marketplace-install`, and let the sync workflow update the protected no-MCP branch.
