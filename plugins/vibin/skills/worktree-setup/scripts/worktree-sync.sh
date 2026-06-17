#!/usr/bin/env bash
# worktree-sync.sh — give a git worktree the same warm, fully-configured
# experience as the main checkout.
#
# A fresh `git worktree add` only materializes *tracked* files. Everything that
# makes a checkout usable but is git-ignored — secrets (.env), local config
# (CLAUDE.md.local, .claude/settings.local.json), tool-trust state (.mise.toml),
# and warm build/dependency caches (node_modules, .venv, target, .next) — is
# missing. This script brings that state across from the main worktree so the
# new worktree is non-degraded from the first command.
#
# Strategy:
#   - COPY  secrets and local config  → each worktree gets its own copy so it
#                                        can diverge safely.
#   - LINK  caches and dependency dirs → shared with the main checkout for an
#                                        instantly warm build (use --copy-caches
#                                        to duplicate instead).
#   - TRUST re-run `mise trust` / `direnv allow` so shell hooks load silently.
#
# Repo-specific additions live in a `.worktree-sync` manifest at the repo root
# (see --help). Defaults cover the common cases with zero configuration.
#
# Usage:
#   worktree-sync.sh [options] [DEST]
#
#   DEST                Worktree to populate. Default: current worktree root.
#
# Options:
#   --from PATH         Source checkout to sync from. Default: the main worktree.
#   --manifest PATH     Manifest file. Default: <source>/.worktree-sync.
#   --copy-caches       Copy cache/dependency dirs instead of symlinking them.
#   --no-caches         Skip cache/dependency dirs entirely.
#   --no-trust          Skip `mise trust` / `direnv allow`.
#   -n, --dry-run       Print actions without changing anything.
#   -v, --verbose       Explain skipped candidates too.
#   -h, --help          Show this help.
#
# Manifest format (lines, # for comments). Paths are relative to the source root:
#   copy  relative/path        # copy file or dir into the worktree
#   link  relative/path        # symlink file or dir into the worktree
#   run   shell command         # run after sync, with cwd = worktree root
set -Eeuo pipefail

SELF=$(basename "$0")

# ---- option parsing --------------------------------------------------------
SOURCE=""
DEST=""
MANIFEST=""
CACHE_MODE="link"   # link | copy | skip
DO_TRUST=1
DRY_RUN=0
VERBOSE=0

die()  { printf '%s: %s\n' "$SELF" "$*" >&2; exit 1; }
note() { printf '  %s\n' "$*"; }
vnote(){ [[ $VERBOSE -eq 1 ]] && printf '  (skip) %s\n' "$*" || true; }

usage() { sed -n '2,/^set -Eeuo/{/^set -Eeuo/!p}' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)        SOURCE=${2:?--from needs a path}; shift 2;;
    --manifest)    MANIFEST=${2:?--manifest needs a path}; shift 2;;
    --copy-caches) CACHE_MODE="copy"; shift;;
    --no-caches)   CACHE_MODE="skip"; shift;;
    --no-trust)    DO_TRUST=0; shift;;
    -n|--dry-run)  DRY_RUN=1; shift;;
    -v|--verbose)  VERBOSE=1; shift;;
    -h|--help)     usage; exit 0;;
    -*)            die "unknown option: $1 (try --help)";;
    *)             [[ -z $DEST ]] && DEST=$1 || die "unexpected argument: $1"; shift;;
  esac
done

command -v git >/dev/null 2>&1 || die "git is required"

# ---- resolve source (main worktree) and dest (target worktree) -------------
if [[ -z $DEST ]]; then
  DEST=$(git rev-parse --show-toplevel 2>/dev/null) \
    || die "not inside a git worktree; pass DEST explicitly"
fi
[[ -d $DEST ]] || die "destination does not exist: $DEST"
DEST=$(cd "$DEST" && pwd)

if [[ -z $SOURCE ]]; then
  # First entry of `git worktree list` is the main worktree.
  SOURCE=$(git -C "$DEST" worktree list --porcelain 2>/dev/null \
            | awk '/^worktree /{print $2; exit}')
  [[ -n $SOURCE ]] || die "could not determine main worktree; pass --from"
fi
[[ -d $SOURCE ]] || die "source does not exist: $SOURCE"
SOURCE=$(cd "$SOURCE" && pwd)

[[ $SOURCE != "$DEST" ]] || die "source and destination are the same checkout ($SOURCE)"

[[ -z $MANIFEST ]] && MANIFEST="$SOURCE/.worktree-sync"

printf '%s\n' "worktree-sync: $SOURCE -> $DEST"
[[ $DRY_RUN -eq 1 ]] && printf '%s\n' "(dry run — no changes will be made)"

# ---- helpers ---------------------------------------------------------------
RSYNC=$(command -v rsync || true)

do_copy() {  # src dest
  local s=$1 d=$2
  [[ $DRY_RUN -eq 1 ]] && { note "copy  $rel"; return; }
  mkdir -p "$(dirname "$d")"
  if [[ -n $RSYNC ]]; then
    rsync -a --delete "$s${3:-}" "$d"
  else
    rm -rf "$d"; cp -a "$s" "$d"
  fi
  note "copy  $rel"
}

do_link() {  # src dest
  local s=$1 d=$2
  # already correctly linked?
  if [[ -L $d && $(readlink "$d") == "$s" ]]; then vnote "link  $rel (already linked)"; return; fi
  [[ $DRY_RUN -eq 1 ]] && { note "link  $rel -> $s"; return; }
  mkdir -p "$(dirname "$d")"
  rm -rf "$d"
  ln -s "$s" "$d"
  note "link  $rel -> $s"
}

# basename patterns that identify copy-worthy secret / local-config files
is_config_file() {
  local b=$1
  case "$b" in
    *.example|*.sample|*.template|*.dist|*.md.example) return 1;;
  esac
  case "$b" in
    .env|.env.*|.envrc|.npmrc|.yarnrc|.yarnrc.yml|.netrc|.pgpass) return 0;;
    *.local|*.local.*) return 0;;            # CLAUDE.md.local, config.local.toml, settings.local.json
    secrets|secrets.*|.secrets|.secrets.*) return 0;;
  esac
  return 1
}

# directory basenames treated as warm caches / dependency stores
is_cache_dir() {
  case "$1" in
    node_modules|.pnpm-store|.yarn|bower_components) return 0;;
    .venv|venv|.tox|.nox|__pypackages__) return 0;;
    target|vendor|.gradle|.m2|build|out|dist) return 0;;
    .next|.nuxt|.svelte-kit|.turbo|.vite|.parcel-cache|.angular|.astro) return 0;;
    .cache|.pytest_cache|.mypy_cache|.ruff_cache|.terraform|.dart_tool) return 0;;
    *) return 1;;
  esac
}

# ---- 1. walk git-ignored entries in the source ----------------------------
# --directory collapses ignored directories to a single `dir/` entry so we do
# not recurse into (huge) node_modules etc.
echo "scanning git-ignored entries..."
while IFS= read -r rel; do
  [[ -z $rel ]] && continue
  rel=${rel%/}
  src="$SOURCE/$rel"
  dst="$DEST/$rel"
  base=$(basename "$rel")
  if [[ -d $src && ! -L $src ]]; then
    if is_cache_dir "$base"; then
      case "$CACHE_MODE" in
        link) do_link "$src" "$dst";;
        copy) do_copy "$src" "$dst" "/";;
        skip) vnote "cache $rel (--no-caches)";;
      esac
    else
      vnote "dir   $rel (not a known cache; add to .worktree-sync if needed)"
    fi
  elif [[ -f $src ]]; then
    if is_config_file "$base"; then
      do_copy "$src" "$dst"
    else
      vnote "file  $rel (not a known config file)"
    fi
  fi
done < <(git -C "$SOURCE" ls-files --others --ignored --exclude-standard --directory 2>/dev/null)

# ---- 2. apply manifest -----------------------------------------------------
RUN_CMDS=()
if [[ -f $MANIFEST ]]; then
  echo "applying manifest: $MANIFEST"
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    line=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [[ -z $line ]] && continue
    verb=${line%% *}
    arg=${line#* }
    case "$verb" in
      copy) rel=$arg; [[ -e "$SOURCE/$arg" ]] && do_copy "$SOURCE/$arg" "$DEST/$arg" || vnote "copy  $arg (missing in source)";;
      link) rel=$arg; [[ -e "$SOURCE/$arg" ]] && do_link "$SOURCE/$arg" "$DEST/$arg" || vnote "link  $arg (missing in source)";;
      run)  RUN_CMDS+=("$arg");;
      *)    die "manifest: unknown verb '$verb' (use copy|link|run)";;
    esac
  done < "$MANIFEST"
else
  vnote "no manifest at $MANIFEST"
fi

# ---- 3. trust shell tooling so hooks load without prompts ------------------
if [[ $DO_TRUST -eq 1 ]]; then
  if command -v mise >/dev/null 2>&1 \
     && ls "$DEST"/.mise.toml "$DEST"/mise.toml "$DEST"/.config/mise/config.toml >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 1 ]]; then note "trust mise ($DEST)"; else
      ( cd "$DEST" && mise trust >/dev/null 2>&1 ) && note "trust mise" || note "trust mise (failed — run 'mise trust' manually)"
    fi
  fi
  if command -v direnv >/dev/null 2>&1 && [[ -f "$DEST/.envrc" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then note "trust direnv ($DEST)"; else
      ( cd "$DEST" && direnv allow >/dev/null 2>&1 ) && note "trust direnv" || note "trust direnv (failed — run 'direnv allow' manually)"
    fi
  fi
fi

# ---- 4. manifest run hooks (after files + trust) ---------------------------
for cmd in "${RUN_CMDS[@]:-}"; do
  [[ -z $cmd ]] && continue
  if [[ $DRY_RUN -eq 1 ]]; then note "run   $cmd"; else
    note "run   $cmd"
    ( cd "$DEST" && eval "$cmd" )
  fi
done

echo "done."
