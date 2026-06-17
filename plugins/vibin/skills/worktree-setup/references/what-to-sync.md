# What to sync into a worktree

A fresh `git worktree add` checks out only **tracked** files. Everything
git-ignored is missing. This catalog is what to bring across, how (copy vs
symlink), and why. Use it when analyzing a repo that has no setup script yet.

Discover the actual git-ignored state of a repo with:

```bash
git -C <main-checkout> ls-files --others --ignored --exclude-standard --directory
```

The `--directory` flag collapses large ignored directories (e.g. `node_modules`)
to a single entry so the output stays readable.

## Copy — secrets and per-worktree config

Copy these so each worktree owns its copy and can diverge safely. Never symlink
secrets (a symlink shares one file across worktrees and leaks edits).

| What | Examples |
|---|---|
| Env / secrets | `.env`, `.env.local`, `.env.development`, `.env.*.local`, `.envrc` |
| Package-manager auth | `.npmrc`, `.yarnrc`, `.yarnrc.yml`, `.netrc`, `.pgpass` |
| Agent / editor local config | `CLAUDE.md.local`, `.claude/settings.local.json`, `.claude/.env`, `.cursor/` local, `.vscode/settings.json` (if git-ignored) |
| Other local config | `config.local.toml`, `*.local`, `*.local.*`, `.mcp.json` (if git-ignored) |

Do **not** copy `*.example`, `*.sample`, `*.template`, `*.dist` — those are
tracked and already present in the worktree.

Note: `~/.claude/settings.local.json` lives in `$HOME`, which all worktrees
already share — no action needed. Only the **project-level**
`.claude/settings.local.json` needs copying.

## Symlink — warm caches and dependency stores

Symlink these from the main checkout so the worktree shares them and the first
build/test is warm, not cold. Symlinking is instant and costs no disk. Copy
instead (`--copy-caches`) only if the branch must diverge these without touching
the main checkout.

| Ecosystem | Dirs |
|---|---|
| Node / JS | `node_modules`, `.pnpm-store`, `.yarn`, `bower_components` |
| Python | `.venv`, `venv`, `.tox`, `.nox`, `__pypackages__` |
| Rust | `target` |
| Go / PHP | `vendor` |
| JVM | `.gradle`, `build`, `.m2` |
| JS build caches | `.next`, `.nuxt`, `.svelte-kit`, `.turbo`, `.vite`, `.parcel-cache`, `.angular`, `.astro` |
| Tool caches | `.cache`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`, `.terraform`, `.dart_tool` |

### When deps changed on the branch

Symlinking shares the main checkout's installed deps. If the branch changes the
lockfile (`package-lock.json`, `pnpm-lock.yaml`, `uv.lock`, `Cargo.lock`, …),
keep the symlink for warmth but reconcile against the branch's manifest with a
post-sync step (a `.worktree-sync` `run` line or a manual reinstall):

```
run pnpm install      # or: uv sync / cargo fetch / go mod download
```

## Trust — make shell tooling load silently

Re-run trust so per-directory shell hooks load without prompts or errors:

- **mise** — `.mise.toml` / `mise.toml` / `.config/mise/config.toml` → `mise trust`
  (otherwise: "not a trusted directory").
- **direnv** — `.envrc` → `direnv allow` (otherwise direnv refuses to load it).
- **asdf** — `.tool-versions` is tracked, so no trust step is needed; just make
  sure the toolchain is installed (`asdf install`).

## Ask — large or stateful data

Don't guess on these — ask the user whether to share (symlink), copy, or skip:

- local databases / volumes (`*.sqlite`, `pgdata/`, `data/`, Docker volumes)
- media, fixtures, downloaded datasets, model weights, large caches
- anything that is both large and may need to diverge per branch

## Decision rule

- **Copy** what should diverge per worktree → secrets, local config.
- **Symlink** what should stay shared and warm and is safe to share → deps,
  build caches.
- **Reinstall** (a `run` step) when the branch changed the lockfile.
- **Ask** when large data might need to diverge.
