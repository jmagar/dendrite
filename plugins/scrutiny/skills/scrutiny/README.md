# Scrutiny

Use when checking Scrutiny SMART drive health, disk failures, temperatures, and storage-device status.

## Usage

Invoke this skill when the user request matches the trigger conditions in `SKILL.md`. The skill body is the source of truth for workflow steps, safety rules, and operational constraints.

## Configuration

Configure `scrutiny_url` in Claude plugin settings or Gemini extension settings.
The plugin hook writes
`${XDG_CONFIG_HOME:-~/.config}/lab-scrutiny/config.env`; legacy `~/.lab/.env`
remains a local fallback during migration.

## Files

- `SKILL.md` - agent workflow and trigger guidance
- `agents/` - OpenAI runtime metadata
- `README.md` - packaging overview
- `CHANGELOG.md` - packaging change history
