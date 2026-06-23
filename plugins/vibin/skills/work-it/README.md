# work-it

End-to-end worktree execution workflow: take a plan file, prepare or reuse a safe worktree, copy the plan into it, open an early draft PR, dispatch an implementation agent, run mandatory review waves, address PR comments, verify merge readiness, save the session log, and publish through `vibin:quick-push`.

## What it does

1. **Worktree** — create a fresh `.worktrees/<slug>` checkout from local main/default checkouts, or reuse the current worktree when it is clearly owned and quiet.
2. **Dispatch implementation** — send an agent into the worktree to run `superpowers:executing-plans`; it iterates until tests/lints/build are green.
3. **PR immediately** — open a draft PR as soon as the branch can support it so progress is visible through commits and CI.
4. **Independent review** — run `lavra:lavra-review` or the closest full independent review equivalent.
5. **PR Review Toolkit sweep** — invoke `vibin:review-pr` in `apply-fixes` mode for code, tests, comments, silent failures, type design, docs/config drift, and simplification.
6. **Repeat reviews** — keep running review/fix waves until new passes show diminishing returns.
7. **Address PR comments and CI** — fetch, fix, verify, push, and resolve every actionable comment and failing check.
8. **Log and publish commits** — run `vibin:quick-push` before the final readiness gate so the session log is committed and pushed as part of the HEAD being validated.
9. **Merge readiness** — invoke `vibin:merge-status` and treat `not_ready`, `blocked`, or `unverified` as a loop-back or blocker.
10. **Final status** — do not create new commits after the final gate; push only already-validated commits and re-check CI for the pushed HEAD.

Completion standard: every plan item implemented, mandatory reviews clean, lint/tests/CI green, merge-status ready, PR comments resolved, session logging complete, and the worktree clean.

## Invoke

Triggers: "work it", execute a `superpowers:executing-plans` document in a worktree, run a complete review-and-fix loop over all touched files.

## Files

- `SKILL.md` — the workflow + non-negotiables + implementation/review agent dispatch guidance
- `agents/openai.yaml` — OpenAI runtime metadata
