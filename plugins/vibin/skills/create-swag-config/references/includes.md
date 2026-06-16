# SWAG Include Files

These paths are inside the SWAG container as `/config/nginx/<file>.conf`.
Confirm they exist on the target host before using a provider-specific include.

## Always

| Include | Purpose |
|---|---|
| `ssl.conf` | TLS settings and certificate wiring. |
| `proxy.conf` | Shared upstream proxy headers and websocket handling. |
| `resolver.conf` | DNS resolver for container names and upstream hosts. |

## MCP-Aware Services

| Include | Purpose |
|---|---|
| `mcp-server.conf` | Server-level MCP/OAuth discovery, origin validation variables, and related routes. |
| `mcp-location.conf` | Streaming/CORS/proxy settings for `/mcp` and session routes. |

Only include these when the target SWAG host provides them and the upstream
service actually exposes MCP/session routes.

## Auth Overlays

Use zero or one provider. Pair the server include with its matching location
include.

| Provider | Server include | Location include |
|---|---|---|
| Authelia | `authelia-server.conf` | `authelia-location.conf` |
| Authentik | `authentik-server.conf` | `authentik-location.conf` |
| Tinyauth | `tinyauth-server.conf` | `tinyauth-location.conf` |
| LDAP | `ldap-server.conf` | `ldap-location.conf` |

If the upstream owns auth, use no external auth overlay.

## QUIC / HTTP3

Only add QUIC or HTTP3 directives when nearby configs on the same SWAG host
already show the supported local pattern. Do not invent `listen ... quic`,
`http3`, or provider-specific include lines from memory; SWAG image versions and
site-confs vary.
