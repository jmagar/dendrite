#!/usr/bin/env bash
# Uptime Kuma HTTP read helper.
# Usage: uptime-kuma-api.sh <command> [args...]

set -euo pipefail

load_config() {
  local config="${UPTIME_KUMA_ENV_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/lab-uptime-kuma/config.env}"
  if [[ -f "$config" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$config"
    set +a
  fi
  : "${UPTIME_KUMA_URL:?set UPTIME_KUMA_URL in plugin settings}"
  UPTIME_KUMA_URL="${UPTIME_KUMA_URL%/}"
}

metrics() {
  : "${UPTIME_KUMA_METRICS_API_KEY:?set UPTIME_KUMA_METRICS_API_KEY in plugin settings}"
  curl -sS -u ":${UPTIME_KUMA_METRICS_API_KEY}" "${UPTIME_KUMA_URL}/metrics"
}

usage() {
  cat <<'EOF'
Usage: uptime-kuma-api.sh <command> [args...]

Commands:
  metrics                      Raw Prometheus metrics
  down                         Current monitors with monitor_status 0
  response-times               monitor_response_time metrics
  certs                        Certificate validity and days remaining
  status-page [slug]           Public status page config JSON
  heartbeat [slug]             Public status page heartbeat JSON
EOF
}

cmd="${1:-help}"
shift || true
case "$cmd" in
  help|-h|--help) usage; exit 0 ;;
esac
load_config

case "$cmd" in
  metrics) metrics ;;
  down) metrics | grep '^monitor_status' | grep ' 0$' || true ;;
  response-times) metrics | grep '^monitor_response_time' || true ;;
  certs) metrics | grep -E '^monitor_cert_(days_remaining|is_valid)' || true ;;
  status-page)
    slug="${1:-${UPTIME_KUMA_STATUS_SLUG:-}}"
    : "${slug:?status page slug required}"
    curl -sS "${UPTIME_KUMA_URL}/api/status-page/${slug}"
    ;;
  heartbeat)
    slug="${1:-${UPTIME_KUMA_STATUS_SLUG:-}}"
    : "${slug:?status page slug required}"
    curl -sS "${UPTIME_KUMA_URL}/api/status-page/heartbeat/${slug}"
    ;;
  *) usage >&2; exit 2 ;;
esac
