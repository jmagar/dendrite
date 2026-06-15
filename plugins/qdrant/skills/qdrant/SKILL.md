---
name: qdrant
description: "This skill should be used when the user asks to inspect, operate, or troubleshoot a Qdrant vector database. Triggers include: \"list Qdrant collections\", \"create a collection\", \"inspect collection config\", \"upsert points\", \"query points\", \"run similarity search\", \"find nearest neighbors\", \"check Qdrant health\", \"embedding storage\", or \"vector database is down\"."
---

# Qdrant

Vector database for semantic search and embeddings. Use the Qdrant REST API for
direct collection, point, and search operations.

## How to call it

Prefer `scripts/qdrant-api.sh` for common collection and point operations. It
loads `QDRANT_URL` and optional `QDRANT_API_KEY` from the environment or
`~/.lab/.env`, adds the API key header only when present, and exposes `health`,
`collections`, `collection`, `create`, `scroll`, `query`, `upsert`, and
`delete-collection`.

Read connection settings from the environment first, then from `~/.lab/.env` if
present. Do not print secrets, and do not add real API keys to repo examples or
committed files.

```bash
read_lab_env() {
  awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' ~/.lab/.env 2>/dev/null
}

QDRANT_URL=${QDRANT_URL:-$(read_lab_env QDRANT_URL)}
QDRANT_API_KEY=${QDRANT_API_KEY:-$(read_lab_env QDRANT_API_KEY)}
: "${QDRANT_URL:?Set QDRANT_URL in the environment or ~/.lab/.env}"
AUTH=(); [ -n "$QDRANT_API_KEY" ] && AUTH=(-H "api-key: $QDRANT_API_KEY")
```

`QDRANT_API_KEY` is optional. Include the `api-key` header only when it is set.
Never echo the key or paste it into chat.

## Common operations

| Intent | Request |
|---|---|
| Server health / version | `curl -sS "${AUTH[@]}" "$QDRANT_URL/"` |
| List collections | `curl -sS "${AUTH[@]}" "$QDRANT_URL/collections"` |
| Collection info | `curl -sS "${AUTH[@]}" "$QDRANT_URL/collections/<name>"` |
| Create collection | `curl -sS -X PUT "${AUTH[@]}" -H 'Content-Type: application/json' "$QDRANT_URL/collections/<name>" -d '{"vectors":{"size":<dim>,"distance":"Cosine"}}'` |
| Delete collection (**destructive**) | `curl -sS -X DELETE "${AUTH[@]}" "$QDRANT_URL/collections/<name>"` |
| Upsert points | `curl -sS -X PUT "${AUTH[@]}" -H 'Content-Type: application/json' "$QDRANT_URL/collections/<name>/points?wait=true" -d '{"points":[{"id":1,"vector":[...],"payload":{}}]}'` |
| Query nearest points | `curl -sS -X POST "${AUTH[@]}" -H 'Content-Type: application/json' "$QDRANT_URL/collections/<name>/points/query" -d '{"query":[...],"limit":10,"with_payload":true}'` |
| Scroll points | `curl -sS -X POST "${AUTH[@]}" -H 'Content-Type: application/json' "$QDRANT_URL/collections/<name>/points/scroll" -d '{"limit":10,"with_payload":true,"with_vector":false}'` |

Full REST reference: <https://api.qdrant.tech/>

## Destructive actions

Deleting a collection (`DELETE /collections/<name>`) removes all of its data and
is irreversible. Confirm with the user before running it. Also confirm before
large point deletions, shard changes, snapshot restores, or collection
recreation.

## Configuration

`QDRANT_URL` is required. `QDRANT_API_KEY` is optional. Prefer existing
environment/plugin settings; use `~/.lab/.env` only as a local runtime source,
not as committed configuration. Verify connectivity:

```bash
curl -sS "${AUTH[@]}" "$QDRANT_URL/" -w '\nHTTP %{http_code}\n'
```

If the local Labby gateway exposes a Qdrant tool, use that managed tool instead
of raw curl after confirming its live schema. Raw REST remains the fallback for
direct instance work.

## When NOT to use this skill

- The user is asking about a different homelab service — load that service's skill instead.
- The user wants to *generate* embeddings, not store or search them - use the
  `tei` skill.
