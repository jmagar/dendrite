---
name: bytestash
description: "This skill should be used when the user asks to save a snippet, store code, create a snippet, search snippets, find a snippet, share a snippet, list snippets, delete a snippet, add to ByteStash, or mentions ByteStash or snippet management."
---

# ByteStash Skill

## Purpose

ByteStash is a self-hosted code snippet management service with multi-file support, sharing capabilities, and organization features. This skill provides **read-write** access to manage snippets with full CRUD operations.

**Capabilities:**
- **Read-only**: List, search, and retrieve snippets
- **Create/Update**: Save new snippets with multiple code fragments
- **Delete**: Remove snippets with user confirmation
- **Share Management**: Create, view, and delete share links (public/protected/expiring)
- **Organization**: Categorize and organize snippets with tags

**Authentication:** JWT via the `bytestashauth: bearer <token>` header.

> **Warning: API keys do NOT work for snippet writes on ByteStash ≤ 1.0.0.** Its
> `authenticateToken` middleware ignores `req.apiKey` and still demands a JWT, so
> `x-api-key` returns `401 Authentication required` on `/api/snippets`. The wrapper
> therefore authenticates with a JWT (login or a pre-minted token). API keys only
> work on the read-only public endpoints (`/api/public/snippets`). This is fixed on
> ByteStash `main` (the `if (req.apiKey) return next()` bypass) — once released,
> `x-api-key` will work for writes again.

## Setup

Configure credentials through the plugin userConfig when possible. The plugin
hook writes `${XDG_CONFIG_HOME:-~/.config}/lab-bytestash/config.env` with mode
`600`; `~/.lab/.env` is only a migration fallback.

```bash
BYTESTASH_URL="https://bytestash.example.com"
BYTESTASH_USERNAME="<your_username>"
BYTESTASH_PASSWORD="<your_password>"     # recommended: wrapper logs in each run, never expires
# --- or, instead of username/password: ---
BYTESTASH_TOKEN="<a_jwt>"                 # pre-minted JWT (expires; login is more durable)
BYTESTASH_API_KEY="<your_api_key>"        # optional; only useful for /api/public reads (and future versions)
```

The wrapper resolves auth in this order: `BYTESTASH_TOKEN` → `BYTESTASH_USERNAME`+`BYTESTASH_PASSWORD`
(via `POST /api/auth/login`). Override the env file path with `BYTESTASH_ENV_FILE`.

**How to get credentials:**
- **Username/password** (recommended): your normal ByteStash login. The wrapper
  exchanges it for a fresh 24h JWT on every run, so nothing expires.
- **Token**: mint a JWT (`jwt.sign({id,username}, JWT_SECRET)`) or copy `bytestash_token`
  from your browser's cookies/localStorage. Note JWTs expire (default 24h).

**Security:**
- Set fallback env permissions with `chmod 600 ~/.lab/.env` if you use it
- NEVER commit `.env` to version control
- A stored `BYTESTASH_TOKEN` is a standing credential — revoke by rotating the
  server's `JWT_SECRET`. Prefer username/password where possible.

## Commands

All commands use the bash wrapper `scripts/bytestash-api.sh`. Run it from this
skill directory (or call it by absolute path); output is JSON by default. These
five cover the common path — the full command catalog (update, push,
share/unshare/view-share, jq recipes, bulk workflows) is in
`references/quick-reference.md`.

```bash
# List all snippets
./scripts/bytestash-api.sh list

# Search by title (case-insensitive partial match)
./scripts/bytestash-api.sh search "docker"

# Search by category
./scripts/bytestash-api.sh search --category "bash"

# Get one snippet's full detail
./scripts/bytestash-api.sh get <snippet-id>

# Create a single-fragment snippet
./scripts/bytestash-api.sh create \
  --title "Docker Compose Example" \
  --categories "docker,devops" \
  --code "version: '3.8'..." \
  --language "yaml" \
  --filename "docker-compose.yml"
```

Multi-file snippets use `push --files "a.py,b.txt,Dockerfile"`; each file becomes
an ordered fragment (`file_name`, `code`, `language`, `position`). The full
snippet data model is documented in `references/api-endpoints.md`.

## Safety

- `delete <snippet-id>` permanently removes the snippet and all fragments, and
  prompts for confirmation. Always confirm with the user first.
- `unshare <share-id>` invalidates a share link (the snippet remains).
- No bulk operations — snippets are processed individually.

## Reference

- `references/quick-reference.md` — full command catalog, jq filters, and bulk workflows
- `references/api-endpoints.md` — complete REST API reference and snippet data model
- `references/troubleshooting.md` — auth (401 on ≤1.0.0), connectivity, and share-endpoint failures
- Official API docs: `{BYTESTASH_URL}/api-docs/` — Web UI: `{BYTESTASH_URL}`

---

## Agent Tool Usage

Run this skill's scripts from this skill directory.

```bash
./scripts/bytestash-api.sh [args]
```
