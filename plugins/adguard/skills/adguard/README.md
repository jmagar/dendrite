# AdGuard

Use when operating AdGuard Home: status, DNS filtering, recent query logs, blocked domains, and network-level ad-blocking checks.

## Usage

Invoke this skill when the user request matches the trigger conditions in `SKILL.md`. The skill body is the source of truth for workflow steps, safety rules, and operational constraints.

## Files

- `SKILL.md` - agent workflow and trigger guidance
- `scripts/adguard-api.sh` - repeatable AdGuard Home control API helper
- `agents/` - OpenAI runtime metadata
- `README.md` - packaging overview
- `CHANGELOG.md` - packaging change history
