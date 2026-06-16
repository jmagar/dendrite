# Qdrant

Use when inspecting, operating, or troubleshooting Qdrant collections, points, search, and vector database health.

## Usage

Invoke this skill when the user request matches the trigger conditions in `SKILL.md`. The skill body is the source of truth for workflow steps, safety rules, and operational constraints.

## Configuration

Configure `qdrant_url` and optional sensitive `qdrant_api_key` in Claude plugin
settings or Gemini extension settings. The plugin hook writes
`${XDG_CONFIG_HOME:-~/.config}/lab-qdrant/config.env`; legacy `~/.lab/.env`
remains a local fallback during migration.

## Files

- `SKILL.md` - agent workflow and trigger guidance
- `scripts/qdrant-api.sh` - repeatable Qdrant REST helper
- `agents/` - OpenAI runtime metadata
- `README.md` - packaging overview
- `CHANGELOG.md` - packaging change history
