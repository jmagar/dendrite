#!/usr/bin/env bash
# Immich API helper.
# Usage: immich-api.sh <command> [args...]

set -euo pipefail

load_config() {
  local config="${IMMICH_ENV_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/lab-immich/config.env}"
  if [[ -f "$config" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$config"
    set +a
  elif [[ -f "$HOME/.lab/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$HOME/.lab/.env"
    set +a
  fi

  : "${IMMICH_URL:?set IMMICH_URL in plugin settings or ~/.lab/.env}"
  : "${IMMICH_API_KEY:?set IMMICH_API_KEY in plugin settings or ~/.lab/.env}"
  IMMICH_URL="${IMMICH_URL%/}"
}

api() {
  local method="$1"
  local endpoint="$2"
  shift 2
  curl -sS -X "$method" \
    -H "Accept: application/json" \
    -H "x-api-key: ${IMMICH_API_KEY}" \
    "$@" \
    "${IMMICH_URL}${endpoint}"
}

usage() {
  cat <<'EOF'
Usage: immich-api.sh <command> [args...]

Commands:
  ping                         Server ping
  version                      Server version
  about                        Server about/info
  statistics                   Server statistics
  me                           Current user
  albums                       List albums
  album <id>                   Album details and assets
  asset <id>                   Asset details
  search <query>               Metadata search
EOF
}

cmd="${1:-help}"
shift || true
case "$cmd" in
  help|-h|--help) usage; exit 0 ;;
esac
load_config

case "$cmd" in
  ping) api GET "/api/server/ping" ;;
  version) api GET "/api/server/version" ;;
  about) api GET "/api/server/about" ;;
  statistics) api GET "/api/server/statistics" ;;
  me) api GET "/api/users/me" ;;
  albums) api GET "/api/albums" ;;
  album)
    id="${1:?album id required}"
    api GET "/api/albums/${id}"
    ;;
  asset)
    id="${1:?asset id required}"
    api GET "/api/assets/${id}"
    ;;
  search)
    query="${1:?query required}"
    payload="$(jq -n --arg query "$query" '{query:$query}')"
    api POST "/api/search/metadata" -H "Content-Type: application/json" -d "$payload"
    ;;
  *) usage >&2; exit 2 ;;
esac
