# Variableized SWAG Config Patterns

Use these as patterns, replacing uppercase placeholders from the Vibin SWAG
configuration or from the user's request.

## Pattern A: Auth-Gated App Plus MCP Routes

Use when the browser app at `/` should be protected by an external auth include,
while `/mcp` and session routes are forwarded to an MCP-capable upstream.

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name SERVICE_NAME.PUBLIC_BASE_DOMAIN;
    include /config/nginx/ssl.conf;
    client_max_body_size 0;

    set $upstream_app "UPSTREAM_APP";
    set $upstream_port "UPSTREAM_PORT";
    set $upstream_proto "UPSTREAM_PROTO";

    set $mcp_upstream_app "MCP_UPSTREAM_APP";
    set $mcp_upstream_port "MCP_UPSTREAM_PORT";
    set $mcp_upstream_proto "MCP_UPSTREAM_PROTO";

    include /config/nginx/mcp-server.conf;
    include /config/nginx/AUTH_METHOD-server.conf;

    location /mcp {
        if ($origin_valid = 0) {
            add_header Content-Type "application/json" always;
            return 403 '{"error":"origin_not_allowed","message":"Origin header validation failed"}';
        }
        include /config/nginx/resolver.conf;
        include /config/nginx/proxy.conf;
        include /config/nginx/mcp-location.conf;
        proxy_pass $mcp_upstream_proto://$mcp_upstream_app:$mcp_upstream_port;
    }

    location ~* ^/(session|sessions) {
        include /config/nginx/resolver.conf;
        include /config/nginx/proxy.conf;
        include /config/nginx/mcp-location.conf;
        proxy_pass $mcp_upstream_proto://$mcp_upstream_app:$mcp_upstream_port;
    }

    location / {
        include /config/nginx/AUTH_METHOD-location.conf;
        include /config/nginx/resolver.conf;
        include /config/nginx/proxy.conf;
        proxy_pass $upstream_proto://$upstream_app:$upstream_port;
    }
}
```

Use `AUTH_METHOD=authelia`, `authentik`, `tinyauth`, or `ldap` only when those
include files exist on the target SWAG host.

If `SWAG_DEFAULT_ENABLE_QUIC=true`, inspect existing configs on the same host
first and add only the QUIC/HTTP3 lines that match that local pattern.

## Pattern B: Upstream Owns Auth

Use when the upstream service handles OAuth/auth end-to-end. Same as Pattern A,
but omit the auth server include and the auth location include.

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name SERVICE_NAME.PUBLIC_BASE_DOMAIN;
    include /config/nginx/ssl.conf;
    client_max_body_size 0;

    set $upstream_app "UPSTREAM_APP";
    set $upstream_port "UPSTREAM_PORT";
    set $upstream_proto "UPSTREAM_PROTO";

    set $mcp_upstream_app "MCP_UPSTREAM_APP";
    set $mcp_upstream_port "MCP_UPSTREAM_PORT";
    set $mcp_upstream_proto "MCP_UPSTREAM_PROTO";

    include /config/nginx/mcp-server.conf;

    location /mcp {
        if ($origin_valid = 0) {
            add_header Content-Type "application/json" always;
            return 403 '{"error":"origin_not_allowed","message":"Origin header validation failed"}';
        }
        include /config/nginx/resolver.conf;
        include /config/nginx/proxy.conf;
        include /config/nginx/mcp-location.conf;
        proxy_pass $mcp_upstream_proto://$mcp_upstream_app:$mcp_upstream_port;
    }

    location ~* ^/(session|sessions) {
        include /config/nginx/resolver.conf;
        include /config/nginx/proxy.conf;
        include /config/nginx/mcp-location.conf;
        proxy_pass $mcp_upstream_proto://$mcp_upstream_app:$mcp_upstream_port;
    }

    location / {
        include /config/nginx/resolver.conf;
        include /config/nginx/proxy.conf;
        proxy_pass $upstream_proto://$upstream_app:$upstream_port;
    }
}
```

## Pattern C: Plain Web App

For non-MCP services, prefer the LinuxServer sample from the target host:

```bash
ssh "$SWAG_EDGE_HOST" 'bash -s' -- "$SWAG_PROXY_CONFS_PATH" <<'REMOTE'
set -euo pipefail
cat "$1/_template.subdomain.conf.sample"
REMOTE
```

Copy that shape, set `server_name SERVICE_NAME.PUBLIC_BASE_DOMAIN`, and proxy
`location /` to `UPSTREAM_PROTO://UPSTREAM_APP:UPSTREAM_PORT`. Add one auth
include pair only if the user wants the app protected by that provider.
