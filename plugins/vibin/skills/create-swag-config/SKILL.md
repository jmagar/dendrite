---
name: create-swag-config
description: 'Use whenever the user wants to add or scaffold a LinuxServer.io SWAG/nginx reverse proxy config: "create a swag config", "add a swag proxy for X", "add X to swag", "make a subdomain config", "expose X on my domain", "add reverse proxy for X", "new subdomain", "proxy X through swag", or "scaffold a swag entry". Uses Vibin-managed SWAG deployment variables instead of hardcoded hostnames/domains. Does not trigger for unrelated nginx work.'
---

# create-swag-config

Create or update a SWAG reverse-proxy config by writing the proxy-confs file
directly. Do not rely on the retired `swag-mcp` marketplace plugin.

## Configuration

Resolve these variables before writing. Prefer the generated config file at
`${XDG_CONFIG_HOME:-$HOME/.config}/lab-swag/config.env`, then environment
variables, then ask the user for anything still missing.

| Variable | Purpose |
|---|---|
| `SWAG_EDGE_HOST` | SSH host that owns the SWAG appdata/config directory. |
| `SWAG_PUBLIC_BASE_DOMAIN` | Base domain for subdomains, such as `example.com`. |
| `SWAG_PROXY_CONFS_PATH` | Host path to SWAG `nginx/proxy-confs`. |
| `SWAG_CONTAINER_NAME` | SWAG container name, default `swag`. |
| `SWAG_DEFAULT_AUTH_METHOD` | Default auth include set, default `authelia`. |
| `SWAG_DEFAULT_UPSTREAM_PROTO` | Default upstream protocol, default `http`. |
| `SWAG_DEFAULT_ENABLE_QUIC` | Default QUIC setting, default `false`. |
| `SWAG_RELOAD_WAIT_SECONDS` | Wait before health check, default `30`. |

Use these shell defaults when the generated config is unavailable:

```bash
source "${XDG_CONFIG_HOME:-$HOME/.config}/lab-swag/config.env" 2>/dev/null || true
: "${SWAG_EDGE_HOST:?set SWAG_EDGE_HOST in Vibin plugin settings or environment}"
: "${SWAG_PUBLIC_BASE_DOMAIN:?set SWAG_PUBLIC_BASE_DOMAIN in Vibin plugin settings or environment}"
: "${SWAG_PROXY_CONFS_PATH:?set SWAG_PROXY_CONFS_PATH in Vibin plugin settings or environment}"
SWAG_CONTAINER_NAME="${SWAG_CONTAINER_NAME:-swag}"
SWAG_DEFAULT_AUTH_METHOD="${SWAG_DEFAULT_AUTH_METHOD:-authelia}"
SWAG_DEFAULT_UPSTREAM_PROTO="${SWAG_DEFAULT_UPSTREAM_PROTO:-http}"
SWAG_DEFAULT_ENABLE_QUIC="${SWAG_DEFAULT_ENABLE_QUIC:-false}"
SWAG_RELOAD_WAIT_SECONDS="${SWAG_RELOAD_WAIT_SECONDS:-30}"
```

## Workflow

1. Normalize the service name to lowercase kebab-case unless the user gives an
   exact config filename. Reject filenames that do not match
   `^[a-z0-9][a-z0-9-]*\.subdomain\.conf$`.
2. Build `config_name=<service>.subdomain.conf` and
   `server_name=<service>.$SWAG_PUBLIC_BASE_DOMAIN`.
3. Validate the filename locally before composing remote paths:
   ```bash
   case "$config_name" in
     *[!a-z0-9.-]*|*/*|*..*) echo "unsafe config name: $config_name" >&2; exit 1 ;;
   esac
   [[ "$config_name" =~ ^[a-z0-9][a-z0-9-]*\.subdomain\.conf$ ]] || exit 1
   ```
4. Inspect existing configs before writing. Pass `SWAG_PROXY_CONFS_PATH` and
   `config_name` as remote script arguments; do not concatenate unchecked names
   into a remote shell string.
5. Pick the config shape:
   - MCP-aware service with browser app gated by auth: include `mcp-server.conf`
     and the matching auth server/location includes.
   - MCP-aware service whose upstream owns OAuth/auth: include `mcp-server.conf`
     but no external auth includes.
   - Plain web app: start from the LinuxServer `_template.subdomain.conf.sample`
     if available and do not add unused MCP locations unless the user asks.
6. Write through a temp file, validate, and roll back automatically if nginx
   rejects the new config. Use the full transaction script in
   `references/fallback-template.md`; the required sequence is:
   ```bash
   tmp=$(mktemp)
   # render config into "$tmp"
   scp "$tmp" "$SWAG_EDGE_HOST:/tmp/$config_name"
   # remote transaction:
   # - copy current target to a timestamped backup when it exists
   # - copy staged file into the proxy-confs directory, then mv into place
   # - run: docker exec "$SWAG_CONTAINER_NAME" nginx -t
   # - on failure, restore the backup or remove the new file, then exit nonzero
   ```
7. Wait for SWAG's file watcher, then verify:
   ```bash
   sleep "$SWAG_RELOAD_WAIT_SECONDS"
   curl -sSI "https://$server_name" | sed -n '1,20p'
   ```

Healthy unauthenticated responses are usually `200`, `302`, `401`, or `403`
depending on the auth layer. Hard failures include `502`, default-backend
`404`, TLS errors, or nginx parse failures.

## Create Shape

For an auth-gated MCP-aware service, collect:

```text
service_name      short service id
server_name       <service>.$SWAG_PUBLIC_BASE_DOMAIN
upstream_app      container name, host, or IP
upstream_port     backend port
upstream_proto    usually http
mcp_upstream_app  usually same as upstream_app
mcp_upstream_port usually same as upstream_port
mcp_upstream_proto usually same as upstream_proto
auth_method       authelia, authentik, tinyauth, ldap, or none
enable_quic       true/false
```

When the user gives only a service and port, ask for or infer `upstream_app`.
Do not invent a private IP or host. If the user says "same host as service X",
inspect the existing config for service X and reuse that pattern.

Only render QUIC/HTTP3 lines when `enable_quic=true` and the target SWAG host
already uses a confirmed QUIC include or listen pattern in nearby configs.
Otherwise leave QUIC disabled even if the variable exists.

## References

- `references/examples.md`: variableized examples for auth-gated MCP,
  upstream-owned auth, and plain web services.
- `references/fallback-template.md`: direct hand-write template and reload
  procedure when no managed helper exists.
- `references/includes.md`: which SWAG include files to use.

## Guardrails

- Confirm before `remove`, full-file overwrite of an existing config, or backup
  cleanup.
- Never put passwords or tokens in nginx config files.
- Do not reintroduce legacy OAuth include files unless the user explicitly asks
  and the target host actually has them.
- Keep one service per `.subdomain.conf`.
