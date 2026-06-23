# Changelog

## Unreleased

- Removed the `summarize` skill from Vibin.
- Removed the duplicate `yt-dlp` skill because the dedicated `ytdl-mcp` marketplace plugin now owns that capability.
- Restored `create-swag-config` to Vibin with variableized SWAG deployment settings after removing the retired standalone `swag-mcp` marketplace entry.
- Removed the `mcp-gateway-tools` skill from Vibin.
- Skill quality pass: fixed the `paperless-ngx` `$SKILL_DIR` script-path bug and stale `.env` guidance, strengthened the `fastmcp-client-cli` description and cleaned placeholder metadata, added a required-vs-optional dependency preamble to `work-it`, clarified `<skill-dir>` resolution in `monolith-check`, and scoped `refresh-docs` to its host pipeline.

## 0.1.0

- Initial Vibin plugin scaffold with quick-push and save-to-md skills.
