# Navidrome

Use when interacting with a self-hosted Navidrome music server through its Subsonic API.

## Usage

Invoke this skill when the user request matches the trigger conditions in `SKILL.md`. The skill body is the source of truth for workflow steps, safety rules, and operational constraints.

## Files

- `SKILL.md` - agent workflow and trigger guidance
- `scripts/navidrome-api.sh` - repeatable Subsonic API helper
- `agents/` - OpenAI runtime metadata
- `references/` - progressively loaded reference material
- `README.md` - packaging overview
- `CHANGELOG.md` - packaging change history
