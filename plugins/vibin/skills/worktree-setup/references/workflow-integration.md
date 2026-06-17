# Workflow integration & precedence

This skill is the **single entrypoint for creating worktrees in our workflow**.
It is tailored to this setup and takes precedence over any other worktree skill.

## Precedence

When any worktree is about to be created or set up, prefer this skill over:

- `superpowers:using-git-worktrees`
- any plugin's generic "create a worktree" / "git worktree" helper
- ad-hoc `git worktree add` run directly by an agent

Reason: those create a **bare** worktree (tracked files only), which is degraded
— no `.env`, cold caches, untrusted `mise`/`direnv`. This skill creates the
worktree under `.worktrees/` **and** brings it to parity with the main checkout.
Other worktree skills may still describe *why* to use worktrees; the *creation
and setup mechanics* go through this skill.

## Triggers

Run this skill **before implementing anything in a new branch/worktree**, and
specifically when any of these begin:

| Trigger | Source | Why it needs a warm worktree |
|---|---|---|
| Creating / adding a worktree | any | the explicit purpose of this skill |
| `lavra-work` | lavra | picks up the locked plan and implements it (auto-routes single vs. multi-bead) |
| `lavra-work-ralph` | lavra | long-running single-agent execution loop |
| `lavra-work-teams` | lavra | parallel multi-agent execution |
| `executing-plans` | superpowers | executes an approved plan |
| `subagent-driven-development` | superpowers | dispatches subagents that build in the worktree |
| `work-it` | vibin | runs a plan to green in `.worktrees/<slug>` |
| Plan mode entered / plan accepted | Claude, Codex, Gemini | implementation is about to start |

The common thread: each of these is the moment **right before code gets
written**. That is exactly when the worktree must already be warm and
configured, so set it up first.

## Plan-mode hook

When a Claude / Codex / Gemini plan is accepted (or plan mode is exited to start
building), the **first implementation step** should be: create the worktree via
this skill (or, if already in a worktree, sync it). Treat "plan accepted" as an
implicit "create-the-worktree" trigger — do not start editing in a bare or
degraded checkout.

## Order of operations

1. **Find an existing setup script first.** If the repo already has a
   worktree/bootstrap/setup script (or Make/just/mise task, `package.json`
   setup), use it — it is the source of truth for that repo.
2. **If found and it creates the worktree**, let it; otherwise create the
   worktree under `.worktrees/<slug>` with `worktree-new.sh` (or
   `git worktree add -b <branch> .worktrees/<slug> HEAD`) and then run the
   repo's sync.
3. **If no script exists**, install one: the full `worktree-sync.sh` engine, or
   the `minimal-worktree-setup.sh` baseline template as a floor, plus a
   `.worktree-sync` manifest for repo-specific extras (see `what-to-sync.md`).
4. **Verify** parity before handing off to the implementing agent/loop.

## Scripts vs. template

- `scripts/worktree-new.sh` — create `.worktrees/<slug>` + sync. The "create a
  worktree" entrypoint.
- `scripts/worktree-sync.sh` — full auto-detecting engine; reads a
  `.worktree-sync` manifest. Use for an existing worktree.
- `references/minimal-worktree-setup.sh` — the bare-minimum baseline to copy
  into a repo and customize when the full engine is more than needed. Every repo
  should have at least this.
