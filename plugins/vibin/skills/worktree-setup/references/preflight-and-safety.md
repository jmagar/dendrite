# Pre-flight & shared-repo safety

You are usually **not alone in this repo.** Other agents and people may have
worktrees, uncommitted work, and in-flight branches. Treat every uncommitted or
unpushed change — yours or not — as precious. Before creating or entering a
worktree, run this pre-flight so nothing is lost and no conflict is a surprise.

## Golden rule

**Never destroy work you did not create, and never destroy uncommitted work at
all without explicit confirmation.** Worktrees share one object store, refs,
stash, config, and hooks — a careless command in one worktree reaches all of
them and the people using them.

## 1. Assess the current checkout before touching anything

```bash
git status --short --branch     # dirty? ahead/behind?
git worktree list               # who else is here, on what branch, at what HEAD
git branch --show-current
```

Key fact that makes worktrees safe: `git worktree add <dest> <base>` checks out
`<base>` into a **new** directory. It does **not** modify the current checkout's
working tree, index, or any other worktree. So a dirty current checkout is safe
— creating a worktree never disturbs it.

The flip side: a new worktree starts from a **committed** ref, so the current
checkout's **uncommitted** changes do **not** come along. Decide deliberately
whether you want them there (next section).

## 2. Carry uncommitted work intentionally (never silently drop it)

If the current checkout is dirty and you want those changes in the new worktree,
move them deliberately. All of these are **non-destructive to other people's
work**:

- **Commit first (best):** commit on the source branch, then base the worktree
  on that commit. Nothing is in limbo.
- **Stash + apply (keeps source intact):**
  ```bash
  git -C <source> stash push -u -m "carry to worktree"   # stash is shared
  # in the new worktree:
  git stash apply stash@{0}    # apply (not pop) so the stash entry survives
  ```
  Use `apply`, not `pop`, until you have confirmed the changes landed; only drop
  the stash once you are sure. Never `git stash clear`/`drop` someone else's
  stash.
- **Patch (fully non-destructive):**
  ```bash
  git -C <source> diff HEAD > /tmp/carry.patch     # tracked changes only
  git -C <dest> apply /tmp/carry.patch
  ```
  The source keeps its changes untouched. (Untracked files are not in
  `diff HEAD` — copy those explicitly.)

If the changes are unrelated to your task, **leave them where they are** — do not
move or "tidy" another worker's in-progress changes.

## 3. Choose the base ref deliberately

`worktree-new.sh <branch> [base-ref]` — `base-ref` defaults to `HEAD`. Pick on
purpose:

| Goal | Base off | How |
|---|---|---|
| Fresh feature, minimize future conflicts | up-to-date integration branch | `git fetch` then base on `origin/main` |
| Continue current work | where you are now | `HEAD` (default) |
| Build on someone's branch | their branch tip | `origin/<their-branch>` |
| Reproduce against a release | a tag/commit | the tag or SHA |

Prefer a **freshly fetched `origin/main`** over a stale local `main` for new
work — basing on a stale ref guarantees a rebase later. Fetch first
(`worktree-new.sh --fetch …`) so the base reflects reality.

## 4. Anticipate conflicts before they happen

Know where your base stands relative to local and remote `main`, and what other
active branches are touching, so a rebase/cherry-pick is planned, not a surprise.

```bash
git fetch origin

# How far does your base diverge from the integration branch?
git rev-list --left-right --count HEAD...origin/main   # "<behind> <ahead>"
git log --oneline HEAD..origin/main                    # what landed since you branched

# Local vs remote main drift
git rev-list --left-right --count main...origin/main

# What are other worktrees/branches changing? Overlap = likely conflicts.
git worktree list
for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
  printf '%s:\n' "$b"; git diff --name-only "main...$b"
done
```

Then decide the integration plan up front:
- **Behind `origin/main`** → expect to `git rebase origin/main` (or merge) before
  opening/finishing the PR.
- **Files overlap an active branch** → expect conflicts in exactly those files;
  coordinate or rebase early while the overlap is small.
- **Local `main` behind `origin/main`** → update your understanding of "main"
  from the remote, not the stale local ref.

Surface this assessment to the user/agent so the cost is known before work
starts.

## 5. Commands that can destroy work — confirm first, scope tightly

These reach shared state or discard uncommitted changes. Do not run them
reflexively; confirm, and target a specific path/worktree, never the whole repo:

- `git reset --hard`, `git checkout -- .`, `git restore .` — discard uncommitted
  changes. Never in a checkout you do not own; never repo-wide to "clean up".
- `git clean -fdx` — deletes untracked files **including** the warm caches and
  `.env` files this skill just placed. Especially dangerous with symlinked
  caches (see below).
- `git worktree remove --force` — removes a worktree with uncommitted/untracked
  changes and loses them. Commit or stash first; remove without `--force` and
  let git refuse if it is dirty.
- `git branch -D`, `git push --force` to a shared branch, `git stash clear/drop`,
  `git gc --prune=now`, ref edits — affect everyone sharing the repo.

## 6. Symlinked caches touch the main checkout

This skill symlinks `node_modules`, `target`, `.next`, etc. from the main
checkout for warmth. Builds in the worktree therefore **write into the main
checkout's** cache. That is fine for incremental caches, but:

- If someone may be **actively building in the main checkout**, prefer
  `--copy-caches` so the worktree gets its own copy and cannot disturb them.
- Never run a destructive clean (`cargo clean`, `rm -rf node_modules`,
  `git clean -fdx`) through a symlink — it deletes the **main** checkout's cache.

## 7. Cleanup, safely

When done with a worktree:

```bash
git -C <worktree> status --short      # confirm nothing uncommitted/unpushed
git worktree remove <worktree>        # refuses if dirty — that's the safety net
git worktree prune                    # only clears already-deleted worktrees
```

Push or preserve any branch you want to keep before removing its worktree.
