# Scrutiny

Inspect Scrutiny SMART drive-health monitoring data through the web API.

## Configuration

Set `scrutiny_url` in Claude plugin settings or Gemini extension settings. The
SessionStart/ConfigChange hook writes:

```bash
${XDG_CONFIG_HOME:-~/.config}/lab-scrutiny/config.env
```

The generated file is mode `600` and is sourced by the skill snippets before the
legacy `~/.lab/.env` fallback.
