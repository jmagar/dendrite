# Immich

Browse and inspect a self-hosted Immich photo/video library through the Immich
REST API. The skill covers server health, version/about metadata, user details,
albums, assets, and metadata search.

## Configuration

Set `immich_url` and sensitive `immich_api_key` in plugin settings. The setup
hook writes:

```bash
${XDG_CONFIG_HOME:-~/.config}/lab-immich/config.env
```

The generated file is mode `600` and is sourced by the skill helper before the
legacy `~/.lab/.env` fallback.

## Skill

- `skills/immich/SKILL.md` — direct API examples and safe read-oriented Immich
  workflows.

## Verify

```bash
plugins/immich/skills/immich/scripts/immich-api.sh ping
```
