# AdGuard

Use when operating AdGuard Home: status, DNS filtering, recent query logs, blocked domains, and network-level ad-blocking checks.

## Usage

Invoke this skill when the user request matches the trigger conditions in `SKILL.md`. The skill body is the source of truth for workflow steps, safety rules, and operational constraints.

## Configuration

Configure `adguard_url`, `adguard_username`, and sensitive `adguard_password` in
Claude plugin settings or Gemini extension settings. The plugin hook writes
`${XDG_CONFIG_HOME:-~/.config}/lab-adguard/config.env`; legacy `~/.lab/.env`
remains a local fallback during migration.

## Files

- `SKILL.md` - agent workflow and trigger guidance
- `scripts/adguard-api.sh` - repeatable AdGuard Home control API helper
- `agents/` - OpenAI runtime metadata
- `README.md` - packaging overview
- `CHANGELOG.md` - packaging change history
