# Direct SWAG Hand-Write Flow

Use this because the standalone `swag-mcp` marketplace plugin is retired or not
available. The target host and paths come from the Vibin SWAG variables.

## Read the Upstream Sample

```bash
source "${XDG_CONFIG_HOME:-$HOME/.config}/lab-swag/config.env" 2>/dev/null || true
ssh "$SWAG_EDGE_HOST" 'bash -s' -- "$SWAG_PROXY_CONFS_PATH" <<'REMOTE'
set -euo pipefail
cat "$1/_template.subdomain.conf.sample"
REMOTE
```

For a plain web service, start from that sample. For MCP-aware services, use
`references/examples.md` and compare against similar existing configs:

```bash
existing_config="EXISTING_SERVICE.subdomain.conf"
ssh "$SWAG_EDGE_HOST" 'bash -s' -- "$SWAG_PROXY_CONFS_PATH" "$existing_config" <<'REMOTE'
set -euo pipefail
case "$2" in *[!a-z0-9.-]*|*/*|*..*) exit 1 ;; esac
sed -n '1,220p' "$1/$2"
REMOTE
```

## Write Safely

Render locally into a temp file, validate the generated filename, copy to the
edge host, back up any existing config, and automatically restore the prior
state if nginx rejects the new file.

```bash
case "$config_name" in
  *[!a-z0-9.-]*|*/*|*..*) echo "unsafe config name: $config_name" >&2; exit 1 ;;
esac
[[ "$config_name" =~ ^[a-z0-9][a-z0-9-]*\.subdomain\.conf$ ]] || exit 1

tmp=$(mktemp)
# render config into "$tmp"
scp "$tmp" "$SWAG_EDGE_HOST:/tmp/$config_name"
ssh "$SWAG_EDGE_HOST" 'bash -s' -- \
  "$SWAG_PROXY_CONFS_PATH" "$config_name" "${SWAG_CONTAINER_NAME:-swag}" <<'REMOTE'
set -euo pipefail
proxy_confs_path=$1
config_name=$2
container_name=${3:-swag}
target="$proxy_confs_path/$config_name"
staged="/tmp/$config_name"
install_tmp="$proxy_confs_path/.$config_name.new.$$"
backup=""

if [ -e "$target" ]; then
  backup="$target.backup.$(date +%Y%m%d%H%M%S)"
  cp -- "$target" "$backup"
fi

cp -- "$staged" "$install_tmp"
mv -- "$install_tmp" "$target"

if ! docker exec "$container_name" nginx -t; then
  if [ -n "$backup" ]; then
    cp -- "$backup" "$target"
  else
    rm -f -- "$target"
  fi
  docker exec "$container_name" nginx -t >/dev/null 2>&1 || true
  exit 1
fi

rm -f -- "$staged"
REMOTE
```

## Verify

```bash
sleep "${SWAG_RELOAD_WAIT_SECONDS:-30}"
curl -sSI "https://$server_name" | sed -n '1,20p'
ssh "$SWAG_EDGE_HOST" "docker logs '${SWAG_CONTAINER_NAME:-swag}' --tail 100"
```

For MCP-aware services, also check the expected well-known endpoint if the
target architecture supports it:

```bash
curl -sS "https://$server_name/.well-known/oauth-authorization-server" | jq .
```
