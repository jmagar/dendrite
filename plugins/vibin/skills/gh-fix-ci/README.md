# gh-fix-ci

Debug and fix failing GitHub PR checks that run in GitHub Actions.

## What it does

1. Locates failing checks on the current PR via `gh pr checks`.
2. Pulls run + job logs for each failure.
3. Summarizes the failure for you.
4. Drafts a fix plan, then continues directly when you asked for a CI fix.
5. Implements the plan, then suggests re-running checks.

External providers (Buildkite, CircleCI, etc.) are explicitly out of scope — only the `link` URL is reported.

## Invoke

Triggers: "CI is failing", "fix the failing checks", "PR checks red", "why is my build broken".

## Prerequisites

`gh` authenticated with `repo` + `workflow` scopes.

## Files

- `SKILL.md` — the workflow
