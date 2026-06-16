# Qdrant

Operate Qdrant vector database collections and points through direct REST helper
scripts.

## Configuration

Set `qdrant_url` and optional sensitive `qdrant_api_key` in Claude plugin
settings or Gemini extension settings. The SessionStart/ConfigChange hook
writes:

```bash
${XDG_CONFIG_HOME:-~/.config}/lab-qdrant/config.env
```

The generated file is mode `600` and is sourced by the skill helper before the
legacy `~/.lab/.env` fallback.
