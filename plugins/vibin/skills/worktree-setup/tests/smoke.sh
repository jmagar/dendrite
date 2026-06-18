#!/usr/bin/env bash
# smoke.sh — regression test for the worktree-setup scripts.
#
# Builds throwaway repos in a temp dir and exercises worktree-new, worktree-sync
# (.worktreeinclude + fallback, caches, --check, --init, submodules), and
# worktree-rm (safe-refuse + clean removal). Prints PASS/FAIL per check and exits
# non-zero if anything failed. Safe to run anywhere; touches only its temp dir.
#
# Usage: tests/smoke.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPTS=$(cd "$HERE/.." && pwd)/scripts
NEW="$SCRIPTS/worktree-new.sh"
SYNC="$SCRIPTS/worktree-sync.sh"
RM="$SCRIPTS/worktree-rm.sh"

# Inject config into EVERY git call (including the scripts' subprocesses) so the
# sandbox works without commit signing and can use file:// submodules.
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=commit.gpgsign      GIT_CONFIG_VALUE_0=false
export GIT_CONFIG_KEY_1=protocol.file.allow GIT_CONFIG_VALUE_1=always
GIT="git"

FAILED=0
ok()  { printf 'PASS: %s\n' "$*"; }
no()  { printf 'FAIL: %s\n' "$*"; FAILED=1; }
check() { if eval "$1"; then ok "$2"; else no "$2 [cond: $1]"; fi; }

TMP=$(mktemp -d)
cleanup() { cd /; rm -rf "$TMP"; }
trap cleanup EXIT

# --- build a main repo ------------------------------------------------------
$GIT init -q "$TMP/repo"; cd "$TMP/repo"
$GIT config user.email t@t.t; $GIT config user.name tester
printf 'node_modules/\n.env\n*.local\nsecret.json\n.claude/settings.local.json\n' > .gitignore
echo app > app.txt; mkdir -p .claude; $GIT add -A; $GIT commit -qm init
# git-ignored state in the main checkout
printf 'SECRET=1\n'        > .env
echo override              > CLAUDE.md.local
echo '{"k":1}'             > secret.json
echo '{"local":true}'      > .claude/settings.local.json
mkdir -p node_modules/pkg; echo dep > node_modules/pkg/index.js
# .worktreeinclude: copy .env + nested claude file, NOT CLAUDE.md.local
printf '.env\n.claude/settings.local.json\n' > .worktreeinclude

echo "== worktree-new + .worktreeinclude =="
"$NEW" feature/login >/dev/null 2>&1
WT="$TMP/repo/.worktrees/feature-login"
check "[[ -d '$WT' ]]"                              "worktree created under .worktrees/"
check "[[ \"\$(cat '$WT/.env' 2>/dev/null)\" == 'SECRET=1' ]]" ".env copied (in .worktreeinclude)"
check "[[ -f '$WT/.claude/settings.local.json' ]]"  "nested claude config copied"
check "[[ ! -e '$WT/CLAUDE.md.local' ]]"            "CLAUDE.md.local NOT copied (not in include)"
check "[[ -L '$WT/node_modules' ]]"                 "node_modules symlinked (warm cache)"
check "[[ \"\$(git -C '$TMP/repo' check-ignore .worktrees 2>/dev/null)\" != '' ]]" ".worktrees is git-ignored"

echo "== worktree-sync --check (clean) =="
if "$SYNC" --check "$WT" >/dev/null 2>&1; then ok "--check reports no gaps on a fresh worktree"; else no "--check reports no gaps on a fresh worktree"; fi

echo "== worktree-sync --check (gap) =="
rm "$WT/.env"
if "$SYNC" --check "$WT" >/dev/null 2>&1; then no "--check detects missing .env"; else ok "--check detects missing .env"; fi
"$SYNC" "$WT" >/dev/null 2>&1   # re-sync to restore
check "[[ -f '$WT/.env' ]]"                          "re-sync restores .env (idempotent)"

echo "== no-clobber + --force =="
printf 'DIVERGED=2\n' > "$WT/.env"
"$SYNC" "$WT" >/dev/null 2>&1
check "[[ \"\$(cat '$WT/.env')\" == 'DIVERGED=2' ]]" "diverged .env not overwritten without --force"
"$SYNC" --force "$WT" >/dev/null 2>&1
check "[[ \"\$(cat '$WT/.env')\" == 'SECRET=1' ]]"   "--force overwrites diverged .env"

echo "== preflight preserves dirty source =="
echo "WIP" >> app.txt; echo scratch > scratch.note
"$NEW" wip/x >/dev/null 2>&1
check "[[ \"\$(tail -1 app.txt)\" == 'WIP' ]]"       "source uncommitted edit preserved"
check "[[ -f scratch.note ]]"                        "source untracked file preserved"
check "[[ ! -e '$TMP/repo/.worktrees/wip-x/scratch.note' ]]" "untracked work not carried into worktree"
$GIT checkout -q -- app.txt; rm -f scratch.note

echo "== worktree-sync --init =="
rm -rf "$TMP/repo2"; $GIT init -q "$TMP/repo2"; cd "$TMP/repo2"
$GIT config user.email t@t.t; $GIT config user.name tester
printf 'node_modules/\n.env\n' > .gitignore
echo '{}' > package-lock.json; echo x > app; $GIT add -A; $GIT commit -qm init
printf 'TOK=1\n' > .env; mkdir -p node_modules/a
"$SYNC" --init >/dev/null 2>&1
check "[[ -f .worktreeinclude ]]"                    "--init wrote .worktreeinclude"
check "grep -q '^.env$' .worktreeinclude"            "--init listed .env in .worktreeinclude"
check "[[ -f .worktree-sync ]]"                      "--init wrote .worktree-sync"
check "grep -q 'npm ci' .worktree-sync"              "--init suggested a reinstall (npm ci)"
cd "$TMP/repo"

echo "== submodules =="
$GIT init -q "$TMP/lib"; ( cd "$TMP/lib"; $GIT config user.email t@t.t; $GIT config user.name t; echo libcode > lib.txt; $GIT add -A; $GIT commit -qm lib )
if $GIT -C "$TMP/repo" submodule add -q "$TMP/lib" vendored-lib >/dev/null 2>&1; then
  $GIT -C "$TMP/repo" commit -qm "add submodule"
  "$NEW" sub/test >/dev/null 2>&1
  check "[[ -f '$TMP/repo/.worktrees/sub-test/vendored-lib/lib.txt' ]]" "submodule populated in new worktree"
else
  echo "SKIP: submodule add unavailable in this environment"
fi

echo "== worktree-rm safety =="
WT2="$TMP/repo/.worktrees/feature-login"
echo "real change" > "$WT2/newwork.txt"; $GIT -C "$WT2" add newwork.txt
if "$RM" feature/login >/dev/null 2>&1; then no "rm refuses worktree with staged work"; else ok "rm refuses worktree with staged work"; fi
check "[[ -d '$WT2' ]]"                              "worktree still present after refusal"
$GIT -C "$WT2" reset -q --hard >/dev/null 2>&1; rm -f "$WT2/newwork.txt"
"$RM" feature/login >/dev/null 2>&1
check "[[ ! -d '$WT2' ]]"                            "rm removes a clean worktree (synced state ignored)"

echo
if [[ $FAILED -eq 0 ]]; then echo "ALL SMOKE TESTS PASSED"; else echo "SOME SMOKE TESTS FAILED"; fi
exit $FAILED
