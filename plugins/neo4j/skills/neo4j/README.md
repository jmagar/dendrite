# Neo4j

Use when querying Neo4j, running Cypher, inspecting graph schema, or checking graph database connectivity.

## Usage

Invoke this skill when the user request matches the trigger conditions in `SKILL.md`. The skill body is the source of truth for workflow steps, safety rules, and operational constraints.

## Configuration

Configure `neo4j_user`, sensitive `neo4j_password`, optional `neo4j_http_url`,
optional `neo4j_url`, and optional `neo4j_db` in Claude plugin settings or
Gemini extension settings. The plugin hook writes
`${XDG_CONFIG_HOME:-~/.config}/lab-neo4j/config.env`; legacy
`~/.lab/.env` remains a local fallback during migration.

## Files

- `SKILL.md` - agent workflow and trigger guidance
- `agents/` - OpenAI runtime metadata
- `README.md` - packaging overview
- `CHANGELOG.md` - packaging change history
