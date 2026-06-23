---
name: memos
description: "This skill should be used when the user asks to save a note, create a memo, search memos, find notes about something, add a note, capture a thought, save something to their note hub, or mentions the Memos service. Does not apply when the user says 'remember this' without specifying Memos — that may route to the mnem memory system instead."
---

# Memos Skill

## Purpose

This skill provides **read-write** access to a self-hosted Memos instance for quick note capture, search, and organization. Memos is a privacy-focused, self-hosted note-taking service with Markdown support, tagging, and file attachments.

**Core capabilities:**
- Create, read, update, and delete memos (notes)
- Search memos by content, tags, or metadata
- Upload and manage file attachments
- Organize memos with tags
- Archive and visibility controls
- Link related memos together

**Primary use case:** Quick capture of important information from Claude conversations into a personal knowledge base.

## Setup

### Prerequisites
- Memos instance running and accessible
- API access token generated from Memos UI
- `curl` and `jq` installed

### Credential Configuration

Configure these values in plugin userConfig. The hook writes
`${XDG_CONFIG_HOME:-~/.config}/lab-memos/config.env` with mode `600`.
Legacy env files are fallback-only during migration:

```bash
# Memos - Self-hosted note-taking service
MEMOS_URL="https://memos.example.com"
MEMOS_API_TOKEN="<your_api_token>"
```

**To generate an API token:**
1. Log into your Memos instance
2. Go to Settings → Access Tokens
3. Click "Create" and copy the generated token
4. Add the token to plugin userConfig, or to `.env` as a local fallback

**Security:**
- Generated config and `.env` files are local-only (never commit)
- The plugin-generated config is written with mode `600`
- Token has same permissions as your user account

## Commands

All commands return JSON output for LLM parsing. Scripts source credentials from
the generated plugin config automatically.

**Invocation:** All script paths below are written relative to the skill
directory, so run them with the skill directory as the working directory (this
is where the Bash tool starts for a skill's own scripts). Each script resolves
its own location internally, so a relative `bash scripts/<name>.sh ...` is all
that is needed — use this `bash scripts/...` form consistently.

### Core scripts

| Script | Covers |
|--------|--------|
| `scripts/memo-api.sh` | create, list, get, update, delete, archive memos |
| `scripts/search-api.sh` | full-text search with tag/date/visibility filters |
| `scripts/tag-api.sh` | list / search / stats / rename tags |
| `scripts/resource-api.sh` | upload, list, delete, download attachments |
| `scripts/user-api.sh` | whoami, tokens, profile |

Common examples:

```bash
# Create / list / get / update / delete / archive
bash scripts/memo-api.sh create "Your memo content here" --tags "work,project"
bash scripts/memo-api.sh list --limit 10 --filter 'tag == "work"'
bash scripts/memo-api.sh get <memo-id>
bash scripts/memo-api.sh update <memo-id> "Updated content"
bash scripts/memo-api.sh delete <memo-id>
bash scripts/memo-api.sh archive <memo-id>

# Search and tags
bash scripts/search-api.sh "docker kubernetes" --tags "devops" --from "2024-01-01"
bash scripts/tag-api.sh list
bash scripts/tag-api.sh search "project-x"

# Attachments and user
bash scripts/resource-api.sh upload image.png --memo-id <id>
bash scripts/user-api.sh whoami
```

Every script supports `--help`. For the full per-command option tables and
worked examples, see `references/quick-reference.md`.

## Workflow

When the user asks about memos:

1. **"Save this to my memos"** → Extract key content, create memo with appropriate tags
2. **"What did I write about X?"** → Search memos by content/tags, present results
3. **"Find my notes on project Y"** → Use tag search or content filter
4. **"Update my memo about Z"** → Search for memo, get ID, update content
5. **"Delete that memo"** → Confirm with user, then delete by ID

## Destructive and Sensitive Actions

Get explicit user confirmation before deleting memos, deleting attachments,
deleting access tokens, creating long-lived access tokens, updating profile
fields, or bulk-renaming tags across memos. Prefer archive over delete when the
user's intent is cleanup rather than permanent removal.

## Notes

### API Details

- **Authentication:** Bearer token in `Authorization` header
- **Base URL:** `/api/v1` endpoint
- **Rate limits:** No documented limits (self-hosted)
- **Pagination:** Uses `pageSize` and `pageToken` parameters
- **Filtering:** Google AIP-160 standard (e.g., `tag == "work"`)

### Memo Format

Memos support full Markdown syntax:
- Headers, lists, code blocks
- Links and images
- Task lists (- [ ] and - [x])
- Tables

### Visibility Options

- `PRIVATE` - Only you can see
- `PROTECTED` - Authenticated users can see
- `PUBLIC` - Anyone can see (RSS feed)

### Best Practices

1. **Use descriptive content:** First line is preview in UI
2. **Tag consistently:** Use lowercase, hyphens for multi-word (e.g., "project-alpha")
3. **Archive old memos:** Keep workspace clean
4. **Link related memos:** Use memo relations for context

### Common Errors

For error diagnosis, see `references/troubleshooting.md`.

## Reference

Bundled references (load as needed):
- `references/api-endpoints.md` — API endpoint details
- `references/quick-reference.md` — command examples
- `references/troubleshooting.md` — common errors and fixes
- `examples/quick-capture.md`, `examples/tagging-workflow.md`, `examples/search-patterns.md` — worked examples

External:
- Official Docs: https://usememos.com/docs
- API Reference: https://usememos.com/docs/api

## Agent Tool Usage

Run this skill's scripts with the Bash tool directly, from the skill directory:

```bash
bash scripts/memo-api.sh [args]
```
