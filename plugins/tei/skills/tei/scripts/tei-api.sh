#!/usr/bin/env bash
# Hugging Face TEI API helper.
# Usage: tei-api.sh <command> [args...]

set -euo pipefail

load_config() {
  if [[ -z "${TEI_URL:-}" && -f "$HOME/.lab/.env" ]]; then
    TEI_URL="$(grep -E '^TEI_URL=' "$HOME/.lab/.env" 2>/dev/null | cut -d= -f2- || true)"
  fi
  : "${TEI_URL:?set TEI_URL in environment or ~/.lab/.env}"
  TEI_URL="${TEI_URL%/}"
}

post_json() {
  local endpoint="$1"
  local payload="$2"
  curl -sS -X POST "${TEI_URL}${endpoint}" \
    -H "Content-Type: application/json" \
    -d "$payload"
}

usage() {
  cat <<'EOF'
Usage: tei-api.sh <command> [args...]

Commands:
  health                       Health check with HTTP status
  info                         Loaded model/runtime info
  embed <text>                 Generate dense embeddings
  embed-batch <json-array>     Generate dense embeddings for JSON array
  sparse <text>                Generate sparse embeddings
  rerank <query> <json-array>  Rerank candidate texts
  tokenize <text>              Tokenize input
  openai-embed <text> [model]  OpenAI-compatible embeddings endpoint
EOF
}

cmd="${1:-help}"
shift || true
case "$cmd" in
  help|-h|--help) usage; exit 0 ;;
esac
load_config

case "$cmd" in
  health) curl -sS "${TEI_URL}/health" -w '\nHTTP %{http_code}\n' ;;
  info) curl -sS "${TEI_URL}/info" ;;
  embed)
    text="${1:?text required}"
    post_json "/embed" "$(jq -n --arg inputs "$text" '{inputs:$inputs}')"
    ;;
  embed-batch)
    json="${1:?JSON array required}"
    post_json "/embed" "$(jq -n --argjson inputs "$json" '{inputs:$inputs}')"
    ;;
  sparse)
    text="${1:?text required}"
    post_json "/embed_sparse" "$(jq -n --arg inputs "$text" '{inputs:$inputs}')"
    ;;
  rerank)
    query="${1:?query required}"
    texts="${2:?JSON array of texts required}"
    post_json "/rerank" "$(jq -n --arg query "$query" --argjson texts "$texts" '{query:$query,texts:$texts}')"
    ;;
  tokenize)
    text="${1:?text required}"
    post_json "/tokenize" "$(jq -n --arg inputs "$text" '{inputs:$inputs}')"
    ;;
  openai-embed)
    text="${1:?text required}"
    model="${2:-tei}"
    post_json "/v1/embeddings" "$(jq -n --arg input "$text" --arg model "$model" '{input:$input,model:$model}')"
    ;;
  *) usage >&2; exit 2 ;;
esac
