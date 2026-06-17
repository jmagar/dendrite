# Changelog

All notable changes to the `worktree-setup` skill are recorded here. Format
roughly follows [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - 2026-06-17
- Initial skill version.
- Added the `worktree-sync.sh` engine: copies git-ignored secrets/local config,
  symlinks known cache/dependency dirs for a warm build, re-runs `mise trust` /
  `direnv allow`, and applies a repo-specific `.worktree-sync` manifest
  (`copy` / `link` / `run`). Touches git-ignored entries only.
- Added the discovery workflow: prefer an existing setup script/task, otherwise
  analyze the repo, install the engine, and generate a tailored manifest.
