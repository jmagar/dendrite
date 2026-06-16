# Neo4j

Operate Neo4j through Cypher over the HTTP transactional API or `cypher-shell`.

## Configuration

Set `neo4j_user`, sensitive `neo4j_password`, optional `neo4j_http_url`,
optional `neo4j_url`, and optional `neo4j_db` in Claude plugin settings or
Gemini extension settings. The SessionStart/ConfigChange hook writes:

```bash
${XDG_CONFIG_HOME:-~/.config}/lab-neo4j/config.env
```

The generated file is mode `600` and is sourced by the skill snippets before the
legacy `~/.lab/.env` fallback.
