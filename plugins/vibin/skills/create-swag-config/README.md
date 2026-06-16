# create-swag-config

Add or update a LinuxServer.io SWAG reverse-proxy config through Vibin. This
skill is intentionally independent of the retired `swag-mcp` marketplace plugin:
it uses configurable deployment variables and direct SSH/file operations.

## Configuration

Set these through Vibin plugin settings, Gemini extension settings, environment
variables, or the generated
`${XDG_CONFIG_HOME:-$HOME/.config}/lab-swag/config.env` file:

| Variable | Purpose |
|---|---|
| `SWAG_EDGE_HOST` | SSH host that owns SWAG config storage. |
| `SWAG_PUBLIC_BASE_DOMAIN` | Base domain for generated subdomains. |
| `SWAG_PROXY_CONFS_PATH` | Host path to `nginx/proxy-confs`. |
| `SWAG_CONTAINER_NAME` | Container name for validation/logs, default `swag`. |
| `SWAG_DEFAULT_AUTH_METHOD` | Default auth provider, default `authelia`. |
| `SWAG_DEFAULT_UPSTREAM_PROTO` | Default upstream protocol, default `http`. |
| `SWAG_DEFAULT_ENABLE_QUIC` | Default QUIC setting, default `false`; only render QUIC lines when the target host already has a confirmed local pattern. |
| `SWAG_RELOAD_WAIT_SECONDS` | Filewatch wait before verification, default `30`. |

The Vibin hook writes the generated config from explicit plugin settings or
environment variables only. It does not read private homelab env files.

## Files

- `SKILL.md` - agent workflow and trigger guidance.
- `agents/openai.yaml` - OpenAI/Codex companion metadata.
- `references/examples.md` - variableized config patterns.
- `references/fallback-template.md` - direct write and verification flow.
- `references/includes.md` - SWAG include-file reference.
