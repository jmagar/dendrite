#!/usr/bin/env bash
# Qdrant API helper.
# Usage: qdrant-api.sh <command> [args...]

set -euo pipefail

read_lab_env() {
  awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$HOME/.lab/.env" 2>/dev/null
}

load_config() {
  local config="${QDRANT_ENV_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/lab-qdrant/config.env}"
  if [[ -f "$config" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$config"
    set +a
  fi
  QDRANT_URL="${QDRANT_URL:-$(read_lab_env QDRANT_URL)}"
  QDRANT_API_KEY="${QDRANT_API_KEY:-$(read_lab_env QDRANT_API_KEY)}"
  : "${QDRANT_URL:?set QDRANT_URL in generated config, environment, or ~/.lab/.env}"
  QDRANT_URL="${QDRANT_URL%/}"
}

api() {
  local method="$1"
  local endpoint="$2"
  shift 2
  local args=(-H "Accept: application/json")
  [[ -n "${QDRANT_API_KEY:-}" ]] && args+=(-H "api-key: ${QDRANT_API_KEY}")
  curl -sS -X "$method" "${args[@]}" "$@" "${QDRANT_URL}${endpoint}"
}

usage() {
  cat <<'EOF'
Usage: qdrant-api.sh <command> [args...]

Commands:
  health                       Server health/version
  collections                  List collections
  collection <name>            Collection info
  create <name> <dim> [dist]   Create collection, default distance Cosine
  scroll <name> [limit]        Scroll points without vectors
  query <name> <json>          POST points/query with raw JSON payload
  upsert <name> <json>         PUT points?wait=true with raw JSON payload
  delete-collection <name>     Delete collection (destructive)
EOF
}

cmd="${1:-help}"
shift || true
case "$cmd" in
  help|-h|--help) usage; exit 0 ;;
esac
load_config

case "$cmd" in
  health) api GET "/" ;;
  collections) api GET "/collections" ;;
  collection)
    name="${1:?collection name required}"
    api GET "/collections/${name}"
    ;;
  create)
    name="${1:?collection name required}"
    dim="${2:?vector dimension required}"
    distance="${3:-Cosine}"
    payload="$(jq -n --argjson size "$dim" --arg distance "$distance" '{vectors:{size:$size,distance:$distance}}')"
    api PUT "/collections/${name}" -H "Content-Type: application/json" -d "$payload"
    ;;
  scroll)
    name="${1:?collection name required}"
    limit="${2:-10}"
    payload="$(jq -n --argjson limit "$limit" '{limit:$limit,with_payload:true,with_vector:false}')"
    api POST "/collections/${name}/points/scroll" -H "Content-Type: application/json" -d "$payload"
    ;;
  query)
    name="${1:?collection name required}"
    payload="${2:?JSON payload required}"
    api POST "/collections/${name}/points/query" -H "Content-Type: application/json" -d "$payload"
    ;;
  upsert)
    name="${1:?collection name required}"
    payload="${2:?JSON payload required}"
    api PUT "/collections/${name}/points?wait=true" -H "Content-Type: application/json" -d "$payload"
    ;;
  delete-collection)
    name="${1:?collection name required}"
    api DELETE "/collections/${name}"
    ;;
  *) usage >&2; exit 2 ;;
esac
