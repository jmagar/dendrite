# Radicale

Manage calendars and contacts on a self-hosted Radicale server through CalDAV
and CardDAV. The skill covers calendar listing, event CRUD, contact search, and
contact CRUD with JSON-oriented helper output.

## Configuration

Set `radicale_url`, `radicale_username`, and sensitive `radicale_password` in
plugin settings. The setup hook writes:

```bash
${XDG_CONFIG_HOME:-~/.config}/lab-radicale/config.env
```

The generated file is mode `600` and is sourced by the skill helper before the
legacy `~/.lab/.env` fallback.

## Skill

- `skills/radicale/SKILL.md` — CalDAV/CardDAV setup, calendar/contact examples,
  and deletion safety.

## Verify

```bash
python plugins/radicale/skills/radicale/scripts/radicale-api.py calendars list
```
