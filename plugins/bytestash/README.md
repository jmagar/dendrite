# ByteStash

Operate a self-hosted ByteStash snippet manager: search snippets, create or
update multi-file snippets, delete snippets with confirmation, and manage share
links.

## Configuration

Set `bytestash_url` plus either `bytestash_username`/sensitive
`bytestash_password` or sensitive `bytestash_token` in plugin settings. The
optional sensitive `bytestash_api_key` is useful for public/read-only API paths
on older ByteStash releases, but snippet writes currently require JWT auth.

The setup hook writes:

```bash
${XDG_CONFIG_HOME:-~/.config}/lab-bytestash/config.env
```

The generated file is mode `600` and is sourced by the skill helper before the
legacy `~/.lab/.env` fallback.

## Skill

- `skills/bytestash/SKILL.md` — full ByteStash API workflow, auth notes, and
  wrapper command examples.

## Verify

```bash
plugins/bytestash/skills/bytestash/scripts/bytestash-api.sh list
```
