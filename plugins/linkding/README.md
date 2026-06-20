# Linkding

Operate a self-hosted Linkding bookmark library: search/list bookmarks, create
bookmarks, update metadata, archive/unarchive, delete with confirmation, manage
tags, and manage bundles.

## Configuration

Set `linkding_url` and sensitive `linkding_api_key` in plugin settings. The setup
hook writes:

```bash
${XDG_CONFIG_HOME:-~/.config}/lab-linkding/config.env
```

The generated file is mode `600` and is sourced by the skill helper before the
legacy `~/.lab/.env` fallback. Local `LINKDING_TOKEN` is accepted as an alias
when `LINKDING_API_KEY` is unset.

## Skill

- `skills/linkding/SKILL.md` — full bookmark, tag, bundle, and deletion-safety
  workflow.

## Verify

```bash
plugins/linkding/skills/linkding/scripts/linkding-api.sh bookmarks
```
