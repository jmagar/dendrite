---
name: linkding
description: "This skill should be used when the user asks to save a bookmark, add or save a link, search bookmarks, list bookmarks, find saved links, tag a bookmark, archive a bookmark, check if a URL is already saved, list tags, or create a bundle. It also applies when the user mentions Linkding by name or asks about their bookmark library."
---

# Linkding Bookmark Manager

Query and manage bookmarks via the Linkding REST API.

## Purpose

This skill provides **read and write** access to your Linkding bookmark library:
- Search and list bookmarks by query, tags, or date
- Add new bookmarks with metadata (title, description, tags)
- Update existing bookmarks
- Archive/unarchive bookmarks
- Delete bookmarks
- Manage tags and bundles (saved searches)
- Check if URLs are already saved

Operations include both read and write actions. **Always confirm before deleting bookmarks.**

## Setup

Credentials come from plugin userConfig. The hook writes
`${XDG_CONFIG_HOME:-$HOME/.config}/lab-linkding/config.env`; `~/.lab/.env`
remains a fallback during migration. Do not hand-edit committed files or echo
the API token. `LINKDING_TOKEN` is accepted as a local alias when
`LINKDING_API_KEY` is unset.

## Quick Reference

All commands use the bash wrapper `scripts/linkding-api.sh`; output is JSON. These
cover the common path. The full command catalog (update, archive/unarchive,
delete, tag-create, bundles, date filters) and copy-paste workflow recipes live
in `references/quick-reference.md`.

```bash
# List recent bookmarks (defaults to most recent)
./scripts/linkding-api.sh bookmarks

# Search bookmarks
./scripts/linkding-api.sh bookmarks --query "python tutorial"

# Save a link for later (read-later); --unread is a real create flag
./scripts/linkding-api.sh create "https://example.com" \
  --title "Example Site" --tags "toread" --unread

# Check whether a URL is already saved (returns the existing bookmark + scraped metadata)
./scripts/linkding-api.sh check "https://example.com"

# List all tags
./scripts/linkding-api.sh tags
```

The full bookmark response model (`id`, `url`, `title`, `tag_names`,
`is_archived`, `unread`, `shared`, `date_added`, …) is documented in
`references/api-endpoints.md`.

## Tag updates replace, not append

`update <id> --tags` **replaces** the whole tag set. To add a tag without losing
the others, read the current tags first and pass the merged list:

```bash
current=$(./scripts/linkding-api.sh get 123 | jq -r '.tag_names | join(",")')
./scripts/linkding-api.sh update 123 --tags "${current},reviewed"
```

See `references/quick-reference.md` ("Batch Tag Addition") for applying this
across many bookmarks.

## Safety

- **Delete is permanent** — always confirm with the user before `delete <id>`.
- Tags are created automatically when first used on a bookmark.
- Requires network access to your Linkding server (REST API v1).

## Reference

Bundled references (load as needed):
- `references/quick-reference.md` — full command catalog, jq patterns, and workflow recipes
- `references/api-endpoints.md` — REST API endpoint reference and bookmark response model
- `references/troubleshooting.md` — auth, URL validation, pagination, and connectivity fixes

## Agent Tool Usage

Run this skill's scripts from the skill directory, or use an absolute path when
the current working directory is elsewhere:

```bash
./scripts/linkding-api.sh [args]
```
