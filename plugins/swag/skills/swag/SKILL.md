---
name: swag
description: "Use when the user needs to manage SWAG/nginx reverse-proxy configs: create, list, view, edit, update, remove, back up, inspect logs, or health-check a proxied service. Trigger phrases include \"add proxy config\", \"create reverse proxy\", \"SWAG config\", \"nginx proxy\", \"expose service\", \"proxy configuration\", \"subdomain config\", \"configure SWAG\", \"list proxy configs\", \"SWAG logs\", \"check proxy health\", or \"proxy a service\"."
---

# SWAG Skill

## Mode Detection

**MCP mode** (preferred): Use the available SWAG MCP tool named `swag`. Different agent runtimes may wrap MCP tool names differently, but the underlying action router is `swag`. The server manages nginx proxy configuration files directly through local or SSH-backed storage.

**Fallback**: There is no meaningful curl-only fallback because SWAG config management requires filesystem access. If the MCP server is unavailable, surface that issue and ask the user to restart or reconnect the plugin/server before making changes.

Configuration comes from plugin settings and MCP server environment variables. Do not hand-edit generated local env files unless the user explicitly asks for plugin/server debugging.

---

## MCP Mode - Tool Reference

Single action router: `swag` with an `action` parameter.

### List configurations

```
swag
  action:      "list"
  list_filter: (optional) "all", "active", or "samples"
  query:       (optional) search filter
  offset:      (optional) pagination offset
  limit:       (optional) page size
```

Returns proxy configurations and their status. `active` lists `.conf` files; `samples` lists `.conf.sample` files.

### Create configuration

```
swag
  action:         "create"
  config_name:    (required) config filename, e.g. "jellyfin.subdomain.conf"
  server_name:    (required) public domain, e.g. "jellyfin.example.com"
  upstream_app:   (required) container name, host, or IP
  upstream_port:  (required) backend port
  upstream_proto: (optional) "http" or "https", defaults to server behavior
  auth_method:    (optional) "authelia", "authentik", "basic", or "none"
  enable_quic:    (optional) true/false
```

Only subdomain-style configs are supported by the current templates. For split routing, also pass `mcp_upstream_app`, `mcp_upstream_port`, and `mcp_upstream_proto`.

### View configuration

```
swag
  action:      "view"
  config_name: (required) config filename
```

### Edit configuration

```
swag
  action:        "edit"
  config_name:   (required) config filename
  new_content:   (required) full replacement file content
  create_backup: (optional) true/false, default true
```

### Update upstream

```
swag
  action:       "update"
  config_name:  (required) config filename
  update_field: (required) "port", "upstream", "app", or "add_mcp"
  update_value: (required) new value
```

`app` expects `host:port`. `add_mcp` expects a path such as `/mcp`.

### Remove configuration

```
swag
  action:        "remove"
  config_name:   (required) config filename
  create_backup: (optional) true/false, default true
```

**DESTRUCTIVE** - removes the nginx config file. Always confirm with the user before executing.

### View logs

```
swag
  action:   "logs"
  log_type: (optional) "nginx-error", "nginx-access", "fail2ban", "letsencrypt", or "renewal"
  lines:    (optional) 1-1000, default 50
```

### Manage backups

```
swag
  action:         "backups"
  backup_action:  (optional) "list" or "cleanup", default "list"
  retention_days: (optional) cleanup retention; 0 uses the server default
```

Cleanup removes old backup files. Confirm before running cleanup.

### Health check

```
swag
  action:           "health_check"
  domain:           (required) public domain to probe
  timeout:          (optional) 1-300 seconds
  follow_redirects: (optional) true/false
```

Probes whether proxied services are accessible.

---

## Typical Workflows

### Expose a new service
1. `action: "list"` - confirm no existing config for the service.
2. `action: "create"` - create the config with `config_name`, `server_name`, `upstream_app`, and `upstream_port`.
3. `action: "health_check"` - verify the public domain is reachable.

### Update a service's backend
1. `action: "view"` - confirm the current config.
2. `action: "update"` - change `port`, `upstream`, or `app`.
3. `action: "health_check"` - verify.

### Diagnose issues
1. `action: "health_check"` - check the public endpoint.
2. `action: "logs"` - review nginx error/access logs.

---

## Destructive Operations

Always confirm before:
- `action: "remove"` - deletes the proxy config.
- `action: "edit"` - replaces the full config content.
- `action: "backups", backup_action: "cleanup"` - deletes old backups.

---

## Proxy Confs Path

The server manages configs at `SWAG_MCP_PROXY_CONFS_PATH` or the SSH URI in `SWAG_MCP_PROXY_CONFS_URI`. These are supplied by plugin settings or server environment. Prefer fixing plugin settings/server configuration over editing generated env files.

---

## Notes

- `subdomain` configs require a wildcard DNS entry or per-subdomain record pointing to SWAG
- Auth methods: `authelia` and `authentik` require those services to be running and configured
- QUIC/HTTP3 requires ports 443/UDP to be open in addition to 443/TCP
