#!/usr/bin/env bash
# AdGuard Home API helper.
# Usage: adguard-api.sh <command> [args...]

set -euo pipefail

load_config() {
  if [[ -f "$HOME/.lab/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$HOME/.lab/.env"
    set +a
  fi
  : "${ADGUARD_URL:?set ADGUARD_URL in ~/.lab/.env}"
  : "${ADGUARD_USERNAME:?set ADGUARD_USERNAME in ~/.lab/.env}"
  : "${ADGUARD_PASSWORD:?set ADGUARD_PASSWORD in ~/.lab/.env}"
  ADGUARD_URL="${ADGUARD_URL%/}"
}

api() {
  local endpoint="$1"
  shift
  curl -sS -u "${ADGUARD_USERNAME}:${ADGUARD_PASSWORD}" "$@" "${ADGUARD_URL}${endpoint}"
}

urlencode() {
  jq -rn --arg v "$1" '$v|@uri'
}

usage() {
  cat <<'EOF'
Usage: adguard-api.sh <command> [args...]

Commands:
  status                       Server status and version
  stats                        DNS query statistics
  querylog [term] [limit]      Query log, optionally filtered
  filtering                    Filtering status and rule lists
  check-host <host>            Check whether a host is blocked
EOF
}

cmd="${1:-help}"
shift || true
case "$cmd" in
  help|-h|--help) usage; exit 0 ;;
esac
load_config

case "$cmd" in
  status) api "/control/status" ;;
  stats) api "/control/stats" ;;
  querylog)
    term="${1:-}"
    limit="${2:-50}"
    endpoint="/control/querylog?limit=${limit}"
    [[ -n "$term" ]] && endpoint="${endpoint}&search=$(urlencode "$term")"
    api "$endpoint"
    ;;
  filtering) api "/control/filtering/status" ;;
  check-host)
    host="${1:?host required}"
    api "/control/filtering/check_host?name=$(urlencode "$host")"
    ;;
  *) usage >&2; exit 2 ;;
esac
