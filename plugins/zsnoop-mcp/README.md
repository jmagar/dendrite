# Zsnoop MCP

ZFS snapshot exploration and recovery through the upstream
[`zsnoop-mcp`](https://github.com/hamsolodev/zsnoop-mcp) stdio MCP server.

The plugin starts the server with:

```bash
uvx zsnoop-mcp
```

Configure hosts in `ZSNOOP_CONFIG`, `$XDG_CONFIG_HOME/zsnoop-mcp/hosts.toml`,
or `~/.config/zsnoop-mcp/hosts.toml`.

## Included

- `.mcp.json` - stdio MCP server registration for `zsnoop`.
- `.claude-plugin/plugin.json` - Claude Code plugin manifest.
- `.codex-plugin/plugin.json` - Codex plugin manifest.
- `gemini-extension.json` - Gemini extension metadata and settings.
- `skills/zsnoop-mcp` - operating skill for discovery, snapshot comparison,
  file recovery, and opt-in restore workflows.

## Notes

`zsnoop-mcp` is read-only by default. Its `restore_file` and `restore_dir`
tools are the only mutating operations and require per-host `allow_restore =
true` plus a non-empty `restore_paths` allowlist in `hosts.toml`.
