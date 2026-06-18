# Changelog

All notable changes to the `worktree-setup` skill are recorded here. Format
roughly follows [Keep a Changelog](https://keepachangelog.com/).

## [0.4.0] - 2026-06-18
- Adopted Claude Code's native **`.worktreeinclude`** file as the primary
  copy mechanism: `worktree-sync.sh` reads it (`.gitignore` syntax) and copies
  only files that match a pattern AND are git-ignored, giving CLI/agent-created
  worktrees parity with Claude's native `--worktree`/subagent behavior. Falls
  back to curated defaults when no `.worktreeinclude` exists.
- Added `--force` (and matching no-clobber semantics): an existing destination
  file is not overwritten unless its contents differ and `--force` is given.
  Added `--include PATH` to override the include file location.
- `.worktree-sync` is now positioned for extras the native file can't express
  (`link` / `run`); docs and the generate-step recommend `.worktreeinclude`
  first and note `WorktreeCreate`/`WorktreeRemove` hooks (incl. non-git VCS).

## [0.3.0] - 2026-06-18
- Added a pre-flight & shared-repo safety layer so worktree work never loses
  uncommitted/unpushed work — yours or anyone else's.
- `worktree-new.sh`: read-only pre-flight before creating — warns when the
  current checkout is dirty (with non-destructive recipes to carry changes),
  lists existing worktrees, and reports how the base diverges from origin's
  default branch so a rebase/conflict is anticipated, not a surprise. Added
  `--fetch` to refresh remote-tracking refs first.
- Added `references/preflight-and-safety.md`: assess dirty state, choose the
  base ref deliberately, carry uncommitted work safely, anticipate conflicts
  (divergence + overlapping branches), avoid destructive/global commands on
  shared state, and clean up worktrees without losing work.
- SKILL.md step 1 is now "Pre-flight & safety", emphasizing that agents are
  rarely alone in a repo and must treat others' work with the same care as
  their own.

## [0.2.0] - 2026-06-17
- Made this the single worktree entrypoint for our workflow, with explicit
  precedence over `superpowers:using-git-worktrees` and other worktree skills.
- Expanded triggers: creating a worktree; `lavra-work` / `lavra-work-ralph` /
  `lavra-work-teams`; `executing-plans`; `subagent-driven-development`;
  `work-it`; Claude/Codex/Gemini plan mode entered or plan accepted; before
  implementing anything in a fresh branch.
- Added `scripts/worktree-new.sh`: create a worktree under `.worktrees/<slug>`
  (ensuring `.worktrees/` is git-ignored) and sync it warm in one step.
- Added `references/minimal-worktree-setup.sh`: a bare-minimum baseline template
  repos can copy and customize.
- Added references: `what-to-sync.md` (copy-vs-symlink catalog by ecosystem) and
  `workflow-integration.md` (triggers + precedence).

## [0.1.0] - 2026-06-17
- Initial skill version.
- Added the `worktree-sync.sh` engine: copies git-ignored secrets/local config,
  symlinks known cache/dependency dirs for a warm build, re-runs `mise trust` /
  `direnv allow`, and applies a repo-specific `.worktree-sync` manifest
  (`copy` / `link` / `run`). Touches git-ignored entries only.
- Added the discovery workflow: prefer an existing setup script/task, otherwise
  analyze the repo, install the engine, and generate a tailored manifest.
