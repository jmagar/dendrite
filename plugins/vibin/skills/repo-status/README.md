# Repo Status

Use when auditing Git checkout state, branches, worktrees, PR/CI state, merge readiness, and cleanup candidates.

The skill treats `marketplace-no-mcp` branches, remote refs, and worktrees as protected long-lived marketplace variants. They should be reported as intentionally preserved and excluded from merge, close, delete, prune, and stale-cleanup recommendations unless Jacob explicitly asks to retire or modify that variant.

## Usage

Invoke this skill when the user request matches the trigger conditions in `SKILL.md`. The skill body is the source of truth for workflow steps, safety rules, and operational constraints.

## Files

- `SKILL.md` - agent workflow and trigger guidance
- `agents/` - OpenAI runtime metadata
- `examples/` - example workflows and usage notes
- `scripts/` - helper scripts used by the skill
- `README.md` - packaging overview
- `CHANGELOG.md` - packaging change history
