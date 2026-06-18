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

**Declare these in `.worktreeinclude`** (Claude Code's native file, repo root,
`.gitignore` syntax). Claude copies matching **git-ignored** files into worktrees
it creates (`--worktree`, subagent worktrees, desktop parallel sessions), and
`worktree-sync.sh` honors the same file so CLI/agent-created worktrees get parity
([tracking issue](https://github.com/anthropics/claude-code/issues/15327)). Only
files that match a pattern **and** are git-ignored are copied, so tracked files
are never duplicated; an existing differing file is not overwritten without
`--force`. Example `.worktreeinclude`:

```gitignore
.env
.env.local
.claude/settings.local.json
config/secrets.json
```

For a non-git VCS, `.worktreeinclude` is not processed — use Claude Code's
`WorktreeCreate` / `WorktreeRemove` hooks instead (see the worktrees docs).

The categories below are what to put in `.worktreeinclude` (and what
`worktree-sync.sh` copies by default when no `.worktreeinclude` exists). Copy —
never symlink — secrets: a symlink shares one file across worktrees and leaks
edits.

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

## Populate — submodules & Git-LFS

These are tracked, so `git worktree add` records them — but the *content* may be
missing, which degrades the worktree just like a missing cache:

- **Submodules** (`.gitmodules` present) → submodule directories are empty until
  `git submodule update --init --recursive` runs. The engine does this
  automatically (skip with `--no-submodules`).
- **Git-LFS** (`.gitattributes` has `filter=lfs`) → files may land as pointer
  text instead of real content. The engine runs `git lfs checkout` (from the
  shared local LFS store, no network); use `git lfs pull` if objects are missing.
  Skip with `--no-lfs`.

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
