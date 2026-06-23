---
name: merge-status
description: Check whether the current branch or worktree is ready to merge, including dirty state, mergeability, conflicts, overlap with other branches/worktrees, lint/tests/CI, stale docs, config/example drift, and live config follow-up.
---

# Merge Status

## Purpose

Use this skill to produce a read-only merge-readiness report for the current
branch, worktree, or PR. Do not mutate the repo unless the user explicitly asks
for fixes.

## Default Command

Start with the bundled collector script from the repository root:

```bash
<skill-dir>/scripts/merge-status.sh
<skill-dir>/scripts/merge-status.sh --json
<skill-dir>/scripts/merge-status.sh --run-checks
```

The script is read-only by default. It fetches remote refs unless `--offline` is
passed, emits a human summary by default, emits structured output with `--json`,
and only executes local lint/test/build commands when `--run-checks` is
explicitly passed. Use the checklist below to interpret the output, fill any
repo-specific gaps the script cannot infer, and decide the final status.

## Evidence Checklist

1. **Dirty state**
   - Prefer `<skill-dir>/scripts/merge-status.sh --json` for collection.
   - Run `git status --short --branch` and `git status --porcelain=v2 --branch`.
   - Report unstaged, staged, untracked, ignored-required, ahead, and behind
     state separately.

2. **Branch and mergeability**
   - Identify current branch, upstream, base branch, HEAD, and open PR if any.
   - Fetch remote refs unless the user asked for an offline check.
   - Check mergeability with the forge CLI when available:
     `gh pr view --json mergeable,reviewDecision,statusCheckRollup,url`.
   - Locally simulate merge risk without changing the working tree. Prefer a
     temporary clone/worktree or `git merge-tree` when available; otherwise use
     `git merge-base`, `git diff --name-only <base>...HEAD`, and report that a
     true merge simulation was unavailable.

3. **Conflicts and overlap**
   - Review any actual conflict markers in touched files.
   - Compare touched files with other open branches and registered worktrees.
   - Report possible conflicts if another branch/worktree touches the same
     files and might merge first.

4. **Lint, tests, and build**
   - Use `<skill-dir>/scripts/merge-status.sh --run-checks` when the user wants
     the skill to execute the discovered local checks.
   - Run the repo's normal lint, test, typecheck, build, and generated-doc
     checks. Prefer documented commands from `CONTRIBUTING.md`, `README.md`,
     `package.json`, `Cargo.toml`, `pyproject.toml`, `Makefile`, `justfile`,
     `Taskfile.yml`, or CI workflow files.
   - If a check is too expensive or unavailable, state the exact reason and the
     command that should be run before merge.

5. **CI status**
   - Use the forge CLI/API when configured. For GitHub:
     `gh pr view --json statusCheckRollup,mergeable,reviewDecision` and
     `gh run list --branch <branch> --limit 10`.
   - CI must be green before reporting merge-ready. Pending, skipped critical,
     failed, or unknown CI means not ready or unverified.

6. **Docs and generated artifacts**
   - Inspect changed files and decide whether docs are stale.
   - Run repo-local generated-doc checks when present.
   - If behavior, CLI flags, config keys, schemas, examples, or user workflows
     changed, verify the matching docs were updated.

7. **Config examples and live config notice**
   - Check `.env.example`, `.env.sample`, `config.toml.example`,
     `config.example.*`, `*.template`, and similar tracked examples for drift
     against new or changed config keys.
   - Check runtime config docs for the same drift.
   - Inform the user when their live `.env`, `config.toml`, or equivalent local
     config may need a matching update. Do not edit live secret/config files
     unless explicitly asked.

## Report Format

Lead with one status:

- `ready_to_merge`
- `not_ready`
- `blocked`
- `unverified`

Then include:

- Branch, HEAD, base, upstream, PR URL.
- Dirty state summary.
- Merge/conflict risk, including overlapping branches/worktrees.
- Lint/test/build/generated-doc commands and results.
- CI status and review status.
- Docs/config-example freshness.
- Live config follow-up notice if applicable.
- Required fixes before merge.

## Completion Standard

Report `ready_to_merge` only when the worktree is clean, local mergeability is
confirmed, linting is clean, all tests pass, generated docs/examples are fresh,
CI is green, review requirements are satisfied, and no unresolved conflict risk
or config drift remains.
