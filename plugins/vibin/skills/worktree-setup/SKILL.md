---
name: worktree-setup
description: Use when creating, adding, or entering a git worktree and the new checkout is missing files that exist in the main checkout, when a worktree feels degraded (no .env, secrets, or local config; cold build/cache; "untrusted directory" or "not a trusted config" from mise/direnv; missing node_modules/.venv/target), or when the user asks to set up, bootstrap, warm, or sync a worktree, or to create/install a worktree-setup script. Goal: make a worktree identical to and as warm as the main local checkout. Bundles a reusable worktree-sync.sh engine.
allowed-tools: "Bash, Read, Write, Edit, Grep, Glob"
---

# Worktree Setup

## Overview

`git worktree add` checks out only **tracked** files. Everything git-ignored —
secrets, local config, tool-trust state, and warm build/dependency caches — is
absent, so the new worktree is degraded: missing `.env`, cold builds, and shell
hooks that error with "not a trusted directory" (`mise`) or refuse to load
(`direnv`).

This skill makes a worktree **identical to and as warm as the main checkout**.
It uses an existing setup script when the repo has one, and otherwise analyzes
the repo, generates a tailored sync, and installs the bundled engine.

The goal is a non-degraded experience: same secrets and configuration, the same
tools and trust, and a warm cache so the first build/test is incremental, not
cold.

## When to Use

- Right after `git worktree add`, before working in the new worktree.
- A worktree is missing `.env` / `.env.local` / secrets / `CLAUDE.md.local` /
  `.claude/settings.local.json`.
- `mise` reports an untrusted directory, or `direnv` won't load `.envrc`.
- The first build/test in a worktree runs cold (no `node_modules`, `.venv`,
  `target`, `.next`, …).
- The user asks to "set up / bootstrap / warm / sync a worktree" or to
  "create a worktree setup script".

## Bundled Engine

`scripts/worktree-sync.sh` is a repo-agnostic engine. Run it from inside the
target worktree (or pass the worktree path as `DEST`):

```bash
# from inside the new worktree — defaults: source = main worktree
<skill-dir>/scripts/worktree-sync.sh --dry-run     # preview
<skill-dir>/scripts/worktree-sync.sh               # apply
```

By default it:
- **copies** git-ignored secret/local-config files (`.env`, `.env.*`, `.envrc`,
  `*.local`, `*.local.*` such as `CLAUDE.md.local` and
  `.claude/settings.local.json`, `.npmrc`, etc.) so each worktree owns its copy;
- **symlinks** known cache/dependency dirs (`node_modules`, `.venv`, `target`,
  `vendor`, `.gradle`, `.next`, `.turbo`, `.cache`, …) for an instantly warm
  build (`--copy-caches` to duplicate, `--no-caches` to skip);
- re-runs `mise trust` / `direnv allow` so shell hooks load silently;
- applies a repo-specific `.worktree-sync` manifest (`copy` / `link` / `run`).

It only ever touches **git-ignored** entries, so it never clobbers tracked
files. Unknown ignored directories are reported, not copied — promote the ones
you want into the manifest.

## Workflow

### 1. Establish worktree context
- `git worktree list` — confirm the main checkout and the target worktree.
- Identify the source (main) and destination (worktree) paths. If no worktree
  exists yet, create one (`git worktree add -b <branch> .worktrees/<slug> HEAD`)
  before syncing.

### 2. Look for an existing setup mechanism (prefer it)
Search the repo before building anything. Check, in order:
- **Scripts:** `scripts/`, `bin/`, repo root — names matching
  `*worktree*`, `*bootstrap*`, `*setup*`, `*sync*`, `postcreate*`, `init*`.
- **Task runners:** `Makefile`, `justfile`/`Justfile`, `Taskfile.yml`,
  `mise.toml`/`.mise.toml` `[tasks]`, `package.json` `scripts`
  (`setup`, `bootstrap`, `postinstall`), `.devcontainer/` `postCreateCommand`.
- **Docs:** `CONTRIBUTING.md`, `README`, `docs/` for a documented setup step.

If one exists: **read it**, then run it correctly (right cwd, required args/env,
inside the worktree). Fill any gaps it leaves (see step 4) but don't duplicate
what it already does. Done — go to step 6.

### 3. Analyze the repo (only if no script exists)
Enumerate what the worktree is missing and classify it:
- **List git-ignored state** that the worktree lacks:
  `git -C <main> ls-files --others --ignored --exclude-standard --directory`
  (the `--directory` flag collapses big ignored dirs so output stays readable).
- **Detect tooling** to know which caches matter and which trust steps are
  needed: `mise`/`.mise.toml`, `direnv`/`.envrc`, `asdf`/`.tool-versions`;
  package managers (`package.json`+lockfile → npm/pnpm/yarn/bun, `uv.lock`/
  `poetry.lock`/`requirements.txt` → Python, `Cargo.toml` → Rust, `go.mod` → Go,
  `build.gradle`/`pom.xml` → JVM); frameworks (Next/Nuxt/Vite/Turbo, etc.).

Classify each item:

| Category | Examples | Action |
|---|---|---|
| Secrets / env | `.env`, `.env.local`, `.env.*`, `.envrc`, `.npmrc` w/ tokens | **copy** (per-worktree, can diverge) |
| Local config | `CLAUDE.md.local`, `.claude/settings.local.json`, `config.local.toml`, `*.local` | **copy** |
| Tool trust | `.mise.toml`, `.envrc` | **run** `mise trust` / `direnv allow` |
| Caches / deps | `node_modules`, `.venv`, `target`, `vendor`, `.gradle`, `.next`, `.turbo` | **symlink** (warm) — copy if the branch will diverge deps |
| Data / large artifacts | DB dumps, media, model weights | **ask** — usually symlink; copy only if it must diverge |

Note: `~/.claude/settings.local.json` lives in `$HOME`, which worktrees already
share — no action needed. Only the *project-level* `.claude/settings.local.json`
needs copying.

### 4. Generate the sync (only if no script exists)
Two parts:
1. **Install the engine.** Copy `scripts/worktree-sync.sh` from this skill into
   the repo (e.g. `scripts/worktree-sync.sh`, preserve the executable bit) so
   the team has it, or run it directly from the skill directory for a one-off.
2. **Write `.worktree-sync`** at the repo root capturing anything the defaults
   miss — repo-specific config files, non-standard cache dirs, and post-sync
   commands. Manifest verbs (paths relative to the source root):
   ```
   copy  config/local.toml          # extra config the defaults don't match
   link  .cache/playwright          # extra warm cache
   run   mise install               # ensure toolchain present
   run   pnpm install --offline     # reconcile deps against this branch
   ```
   Prefer the engine's auto-detection; use the manifest only for the gaps. The
   defaults already handle the common secret/config files and cache dirs.

### 5. Run it
- Dry-run first: `worktree-sync.sh --dry-run -v` and review the plan.
- Apply: `worktree-sync.sh`.
- Re-run is safe (idempotent): config is overwritten, links are reused.

### 6. Verify the worktree is non-degraded
Confirm parity with the main checkout — don't assume:
- Secrets/config present: `.env` and local config exist in the worktree.
- Trust clean: open a shell in the worktree; `mise`/`direnv` load without
  prompts or "untrusted" errors.
- Warm cache: dependency/build dirs resolve (e.g. `node_modules` present,
  `<lockfile>` satisfied) and an incremental build/test is warm, not cold.
- Run the repo's own quick check (lint/build/test smoke) and confirm it behaves
  as it does in the main checkout.

Report what was copied vs. linked, any trust steps run, unknown ignored entries
you chose to skip, and any manual follow-up (e.g. a deps reinstall needed
because the branch changed the lockfile).

## Decision Guide: Copy vs Symlink

- **Copy** anything the worktree should be able to change independently:
  secrets, local config, anything per-branch.
- **Symlink** anything you want shared and warm and that is safe to share:
  dependency stores and build/incremental caches. Symlinking gives an instantly
  warm cache at zero copy cost.
- **Reinstall instead of share** when the branch changes the dependency
  lockfile — symlink for warmth, then `run` the package manager so the worktree
  reconciles against its own manifest.
- When unsure whether large data must diverge, **ask the user**.

## Completion Standard

The worktree is done when it is indistinguishable from the main checkout for
development: same secrets and configuration, the same tools loaded and trusted,
a warm cache, and the repo's normal checks passing. A worktree that builds cold,
prompts about trust, or is missing `.env` is not done.
