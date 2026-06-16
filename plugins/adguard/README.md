# AdGuard Home

Operate AdGuard Home DNS filtering through direct API helper scripts.

## Configuration

Set `adguard_url`, `adguard_username`, and sensitive `adguard_password` in
Claude plugin settings or Gemini extension settings. The
SessionStart/ConfigChange hook writes:

```bash
${XDG_CONFIG_HOME:-~/.config}/lab-adguard/config.env
```

The generated file is mode `600` and is sourced by the skill helper before the
legacy `~/.lab/.env` fallback.
