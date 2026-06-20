# Memos

Operate a self-hosted Memos note hub for quick note capture, search,
organization, tags, visibility, archive state, and file attachments.

## Configuration

Set `memos_url` and sensitive `memos_api_token` in plugin settings. The setup
hook writes:

```bash
${XDG_CONFIG_HOME:-~/.config}/lab-memos/config.env
```

The generated file is mode `600` and is sourced by the skill helper before the
legacy `~/.lab/.env` fallback.

## Skill

- `skills/memos/SKILL.md` — memo CRUD, search, tag, resource, and safety
  workflows.

## Verify

```bash
plugins/memos/skills/memos/scripts/memo-api.sh list --limit 5
```
