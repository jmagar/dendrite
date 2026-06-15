#!/usr/bin/env bash
# MCPJam UI/App validation helper.
# Usage: mcpjam-ui-check.sh <target flags...> [--resource-uri URI] [--tool-name NAME] [--tool-args JSON] [--render]

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  mcpjam-ui-check.sh --url http://127.0.0.1:8001/mcp [options]
  mcpjam-ui-check.sh --command ./server --args mcp --cwd /repo [options]

Target flags are passed through to mcpjam:
  --url URL
  --command COMMAND [--args ARGS] [--cwd DIR]
  --header "Key: Value" / --access-token TOKEN / other mcpjam flags

Options handled by this wrapper:
  --resource-uri URI          Also read the UI resource
  --tool-name NAME            Also call a UI-capable tool
  --tool-args JSON            Tool args JSON, default {}
  --render                    Call tool with --ui --require-render
  --skip-conformance          Skip mcpjam apps conformance
EOF
}

target=()
resource_uri=""
tool_name=""
tool_args="{}"
render=0
skip_conformance=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-uri) resource_uri="${2:?resource uri required}"; shift 2 ;;
    --tool-name) tool_name="${2:?tool name required}"; shift 2 ;;
    --tool-args) tool_args="${2:?tool args JSON required}"; shift 2 ;;
    --render) render=1; shift ;;
    --skip-conformance) skip_conformance=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) target+=("$1"); shift ;;
  esac
done

if [[ ${#target[@]} -eq 0 ]]; then
  usage >&2
  exit 2
fi

run() {
  printf '\n==> %s\n' "$*" >&2
  "$@"
}

command -v mcpjam >/dev/null || { echo "ERROR: mcpjam is not on PATH" >&2; exit 127; }

run mcpjam server doctor "${target[@]}"
if [[ "$skip_conformance" -eq 0 ]]; then
  run mcpjam apps conformance "${target[@]}"
fi
run mcpjam tools list "${target[@]}"
run mcpjam resources list "${target[@]}"

if [[ -n "$resource_uri" ]]; then
  run mcpjam resources read "${target[@]}" --resource-uri "$resource_uri"
fi

if [[ -n "$tool_name" ]]; then
  call_args=(mcpjam tools call "${target[@]}" --tool-name "$tool_name" --tool-args "$tool_args")
  if [[ "$render" -eq 1 ]]; then
    call_args+=(--ui --require-render --quiet --format json)
  fi
  run "${call_args[@]}"
fi
