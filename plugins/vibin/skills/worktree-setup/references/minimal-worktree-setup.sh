#!/usr/bin/env bash
# minimal-worktree-setup.sh — BASELINE TEMPLATE (the bare minimum).
#
# This is the floor for worktree setup: copy it into a repo as
# `scripts/worktree-setup.sh`, then edit the COPY/LINK/TRUST sections to match
# the repo. It is intentionally small and dependency-free so it is easy to read
# and adapt. For zero-config auto-detection and a `.worktree-sync` manifest, use
# the full `worktree-sync.sh` engine instead — this template is what every repo
# should have at minimum if it does not adopt the engine.
#
# What "bare minimum" means: a fresh `git worktree add` only checks out tracked
# files. At minimum a worktree must also get (1) secrets/env, (2) local config,
# and (3) re-trusted shell tooling — otherwise it is degraded. Warm caches are
# strongly recommended; add the ones this repo uses to LINK_DIRS.
#
# Usage:
#   scripts/worktree-setup.sh <branch> [base-ref]   # create .worktrees/<slug> + set up
#   scripts/worktree-setup.sh                        # set up the current worktree
set -Eeuo pipefail

# --- EDIT THESE for your repo ------------------------------------------------
# Files copied from the main checkout (each worktree gets its own copy).
# Tip: Claude Code reads these from a `.worktreeinclude` file (.gitignore syntax)
# natively. List the same paths there so Claude-created worktrees match; this
# template is the floor for git worktrees created by hand.
COPY_FILES=(
  .env
  .env.local
  .envrc
  CLAUDE.md.local
  .claude/settings.local.json
)
# Directories symlinked from the main checkout (shared, instantly warm).
LINK_DIRS=(
  node_modules
  .venv
  # target            # Rust
  # vendor            # Go / PHP
  # .next .turbo      # JS frameworks
)
# -----------------------------------------------------------------------------

main_worktree() { git worktree list --porcelain | awk '/^worktree /{print $2; exit}'; }

ROOT=$(cd "$(main_worktree)" && pwd)

# Resolve / create the destination worktree.
if [[ $# -ge 1 ]]; then
  branch=$1; base=${2:-HEAD}
  slug=$(printf '%s' "$branch" | tr '/' '-')
  DEST="$ROOT/.worktrees/$slug"
  git -C "$ROOT" check-ignore -q .worktrees \
    || echo "warning: .worktrees/ is not git-ignored — add it to .gitignore"
  if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$ROOT" worktree add "$DEST" "$branch"
  else
    git -C "$ROOT" worktree add -b "$branch" "$DEST" "$base"
  fi
else
  DEST=$(git rev-parse --show-toplevel)
fi
DEST=$(cd "$DEST" && pwd)
[[ $ROOT != "$DEST" ]] || { echo "run from / target a worktree, not the main checkout"; exit 1; }

echo "setting up worktree: $DEST"

# 1. COPY secrets + local config.
for f in "${COPY_FILES[@]}"; do
  [[ -e "$ROOT/$f" ]] || continue
  mkdir -p "$DEST/$(dirname "$f")"
  cp -a "$ROOT/$f" "$DEST/$f"
  echo "  copied $f"
done

# 2. LINK warm caches / dependency dirs.
for d in "${LINK_DIRS[@]}"; do
  [[ -d "$ROOT/$d" && ! -L "$ROOT/$d" ]] || continue
  [[ -e "$DEST/$d" ]] && continue
  mkdir -p "$DEST/$(dirname "$d")"
  ln -s "$ROOT/$d" "$DEST/$d"
  echo "  linked $d -> $ROOT/$d"
done

# 3. TRUST shell tooling so hooks load without prompts.
command -v mise   >/dev/null 2>&1 && [[ -f "$DEST/.mise.toml" || -f "$DEST/mise.toml" ]] \
  && ( cd "$DEST" && mise trust >/dev/null 2>&1 ) && echo "  trusted mise"
command -v direnv >/dev/null 2>&1 && [[ -f "$DEST/.envrc" ]] \
  && ( cd "$DEST" && direnv allow >/dev/null 2>&1 ) && echo "  allowed direnv"

echo "done: $DEST"
