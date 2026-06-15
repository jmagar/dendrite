---
name: neo4j
description: "This skill should be used when the user wants to query a Neo4j graph database, run Cypher statements, inspect node labels or relationship types, check schema constraints or indexes, verify Neo4j connectivity, or explore graph data. Triggers include: \"run a Cypher query\", \"what nodes are in my graph\", \"list relationship types\", \"check my Neo4j instance\", \"show me the graph schema\", or any question about graph database queries."
---

# Neo4j

Graph database — nodes, relationships, Cypher queries. Prefer read-only Cypher over Neo4j's **HTTP transactional API**; use `cypher-shell` only when HTTP is not exposed.

## How to call it

```bash
if [ -f "$HOME/.lab/.env" ]; then
  set -a; . "$HOME/.lab/.env"; set +a
fi

: "${NEO4J_DB:=neo4j}"

# Prefer an explicit HTTP endpoint. If only the common bolt:// URL is present,
# derive the default HTTP URL for the same host.
if [ -z "${NEO4J_HTTP_URL:-}" ] && [ -n "${NEO4J_URL:-}" ]; then
  NEO4J_HTTP_URL="$(printf '%s\n' "$NEO4J_URL" | sed -E 's#^bolt(s)?://#http://#; s#:7687/?$#:7474#')"
fi

[ -n "${NEO4J_USER:-}" ] && [ -n "${NEO4J_PASSWORD:-}" ] && [ -n "${NEO4J_HTTP_URL:-}" ] || {
  echo "neo4j not configured - set NEO4J_USER, NEO4J_PASSWORD, and NEO4J_HTTP_URL (or NEO4J_URL) in ~/.lab/.env"
}

AUTH=(-u "$NEO4J_USER:$NEO4J_PASSWORD")
```

Auth is HTTP Basic. `bolt://` URLs are for binary Bolt clients (`cypher-shell`, drivers); curl needs the HTTP listener. Never echo the password.

## Running Cypher

All queries go through `POST /db/<database>/tx/commit` with a `statements` array:

```bash
cypher() {
  jq -n --arg stmt "$1" '{"statements":[{"statement":$stmt}]}' | \
  curl -sS "${AUTH[@]}" -H 'Content-Type: application/json' \
    "$NEO4J_HTTP_URL/db/$NEO4J_DB/tx/commit" \
    -d @-
}
```

| Intent | Cypher (pass to `cypher`) |
|---|---|
| Read query | `MATCH (n) RETURN n LIMIT 25` |
| List node labels | `CALL db.labels()` |
| List relationship types | `CALL db.relationshipTypes()` |
| List constraints | `SHOW CONSTRAINTS` |
| List indexes | `SHOW INDEXES` |
| List databases | `SHOW DATABASES` |
| Server / components info | `CALL dbms.components()` |

Server discovery (available endpoints) is `GET $NEO4J_HTTP_URL/`. Multi-statement transactions are possible by passing several objects in the `statements` array, but do that only when the user explicitly asks.

## Checking the response

The transactional API usually returns HTTP 200 even when Cypher failed. Inspect `.errors` before trusting `.results`:

```bash
cypher 'MATCH (n) RETURN n LIMIT 5' | jq '{errors, results}'
```

Any non-empty `errors` array means the query failed; report the code and message instead of treating the result as empty data.

## Destructive actions

Any write Cypher (`CREATE`, `MERGE`, `SET`, `DELETE`, `DROP`, etc.) mutates the graph. Confirm with the user before running writes or multi-statement transactions that include them.

## Configuration

`NEO4J_USER`, `NEO4J_PASSWORD`, `NEO4J_DB`, `NEO4J_URL` (bolt), and optionally `NEO4J_HTTP_URL` live in `~/.lab/.env`. Verify connectivity:

```bash
curl -sS "${AUTH[@]}" "$NEO4J_HTTP_URL/" -w '\nHTTP %{http_code}\n'
```

If only Bolt is exposed, use `cypher-shell -a "$NEO4J_URL" -u "$NEO4J_USER" -p "$NEO4J_PASSWORD"` instead of curl. Do not pass mutating Cypher this way unless the user explicitly confirmed the write.

## When NOT to use this skill

- The user is asking about a different homelab service — load that service's skill instead.
- The user wants vector search — that's the `qdrant` skill.
