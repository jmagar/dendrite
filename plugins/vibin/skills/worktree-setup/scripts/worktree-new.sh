#!/usr/bin/env bash
# worktree-new.sh — create a worktree under .worktrees/<slug> in the repo and
# immediately sync it warm, so it is non-degraded from the first command.
#
# This is the canonical "create a worktree" entrypoint for our workflow. It
# always places worktrees in <repo>/.worktrees/, creates/uses the branch, makes
# sure .worktrees/ is git-ignored, then runs worktree-sync.sh to bring over
# secrets, local config, warm caches, and tool-trust state.
#
# Usage:
#   worktree-new.sh <branch> [base-ref] [-- <worktree-sync.sh args>...]
#
#   <branch>      Branch to create (or check out if it already exists).
#   [base-ref]    Base for a new branch. Default: HEAD.
#   -- ARGS       Everything after -- is passed through to worktree-sync.sh
#                 (e.g. --copy-caches, --no-caches, --dry-run).
#
# Examples:
#   worktree-new.sh feature/login
#   worktree-new.sh hotfix origin/main
#   worktree-new.sh spike -- --copy-caches
set -Eeuo pipefail

SELF=$(basename "$0")
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
SYNC="$SELF_DIR/worktree-sync.sh"

die() { printf '%s: %s\n' "$SELF" "$*" >&2; exit 1; }

[[ $# -ge 1 ]] || die "usage: $SELF <branch> [base-ref] [-- <sync args>...]"
command -v git >/dev/null 2>&1 || die "git is required"

BRANCH=$1; shift
BASE="HEAD"
SYNC_ARGS=()
if [[ $# -gt 0 && $1 != "--" ]]; then BASE=$1; shift; fi
if [[ ${1:-} == "--" ]]; then shift; SYNC_ARGS=("$@"); fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"

# Repo root = the main worktree (first entry of `git worktree list`).
ROOT=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')
[[ -n $ROOT ]] || die "could not determine main worktree"
ROOT=$(cd "$ROOT" && pwd)

# Slug: branch name made filesystem-friendly (feature/login -> feature-login).
SLUG=$(printf '%s' "$BRANCH" | tr '/' '-' | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-*//; s/-*$//')
[[ -n $SLUG ]] || die "could not derive a slug from branch '$BRANCH'"
DEST="$ROOT/.worktrees/$SLUG"

[[ ! -e $DEST ]] || die "worktree path already exists: $DEST"

# Keep .worktrees/ out of git. Prefer the committed .gitignore; otherwise add a
# local-only exclude so the directory never shows up as untracked.
if ! git -C "$ROOT" check-ignore -q .worktrees 2>/dev/null; then
  EXCLUDE="$(git -C "$ROOT" rev-parse --git-common-dir)/info/exclude"
  if [[ -f $EXCLUDE ]] && ! grep -qxF '/.worktrees/' "$EXCLUDE" 2>/dev/null; then
    printf '/.worktrees/\n' >> "$EXCLUDE"
    printf '%s: added /.worktrees/ to %s (consider committing it to .gitignore)\n' "$SELF" "$EXCLUDE" >&2
  fi
fi

mkdir -p "$ROOT/.worktrees"

# Create the worktree: new branch from BASE, or check out an existing branch.
if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  printf 'creating worktree for existing branch %s\n' "$BRANCH"
  git -C "$ROOT" worktree add "$DEST" "$BRANCH"
else
  printf 'creating worktree with new branch %s from %s\n' "$BRANCH" "$BASE"
  git -C "$ROOT" worktree add -b "$BRANCH" "$DEST" "$BASE"
fi

# Sync it warm.
if [[ -x $SYNC ]]; then
  "$SYNC" "$DEST" ${SYNC_ARGS[@]+"${SYNC_ARGS[@]}"}
else
  printf '%s: %s not found/executable — worktree created but NOT synced\n' "$SELF" "$SYNC" >&2
fi

printf '\nworktree ready: %s\n' "$DEST"
printf 'next: cd %q\n' "$DEST"
