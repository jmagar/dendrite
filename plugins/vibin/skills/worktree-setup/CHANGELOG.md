# Changelog

All notable changes to the `worktree-setup` skill are recorded here. Format
roughly follows [Keep a Changelog](https://keepachangelog.com/).

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
