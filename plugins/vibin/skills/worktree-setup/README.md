# worktree-setup

Make a fresh `git worktree` identical to and as warm as the main checkout, so an
agent (or human) gets a non-degraded experience from the first command.

## Why

`git worktree add` materializes only **tracked** files. Everything git-ignored
is missing in the new worktree:

- secrets / env: `.env`, `.env.local`, `.env.*`, `.envrc`
- local config: `CLAUDE.md.local`, `.claude/settings.local.json`, `*.local`
- tool trust: `.mise.toml` ("not a trusted directory"), `.envrc` (direnv)
- warm caches: `node_modules`, `.venv`, `target`, `vendor`, `.gradle`, `.next`, …

The result is a degraded worktree: no secrets, cold builds, shell hooks erroring
on trust. This skill fixes that.

## What it does

1. **Establish context** — find the main checkout and target worktree.
2. **Prefer an existing script** — search for a worktree/bootstrap/setup script,
   Make/just/mise task, or `package.json` setup; read it and run it correctly.
3. **Analyze (if none)** — enumerate git-ignored state and classify it into
   secrets, local config, trust, caches, and data.
4. **Generate (if none)** — install the bundled `worktree-sync.sh` engine and
   write a repo-specific `.worktree-sync` manifest for the gaps.
5. **Run** — dry-run, then apply (idempotent).
6. **Verify** — secrets present, trust clean, warm cache, repo checks pass.

## The engine: `scripts/worktree-sync.sh`

Repo-agnostic, zero-config defaults. From inside the new worktree:

```bash
scripts/worktree-sync.sh --dry-run   # preview
scripts/worktree-sync.sh             # apply
```

- **copies** git-ignored secret/local-config files (per-worktree, can diverge)
- **symlinks** known cache/dependency dirs (warm; `--copy-caches` / `--no-caches`)
- runs `mise trust` / `direnv allow`
- applies a `.worktree-sync` manifest: `copy <path>` / `link <path>` / `run <cmd>`

It only ever touches git-ignored entries, so it never clobbers tracked files.

## Decision guide

- **Copy** what should diverge per worktree (secrets, local config).
- **Symlink** what should stay shared and warm (deps, build caches).
- **Reinstall** (a `run` step) when the branch changes the lockfile.
- **Ask** before sharing large data that may need to diverge.

## Files

- `SKILL.md` — workflow, classification table, copy-vs-symlink guide
- `scripts/worktree-sync.sh` — the reusable sync engine
- `agents/openai.yaml` — OpenAI runtime metadata
