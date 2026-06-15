# Uptime Kuma

Use when checking service availability, monitor status, uptime percentages, response times, and public status-page data.

## Usage

Invoke this skill when the user request matches the trigger conditions in `SKILL.md`. The skill body is the source of truth for workflow steps, safety rules, and operational constraints.

## Files

- `SKILL.md` - agent workflow and trigger guidance
- `scripts/uptime-kuma-api.sh` - repeatable Uptime Kuma HTTP read helper
- `agents/` - OpenAI runtime metadata
- `references/` - progressively loaded reference material
- `README.md` - packaging overview
- `CHANGELOG.md` - packaging change history
