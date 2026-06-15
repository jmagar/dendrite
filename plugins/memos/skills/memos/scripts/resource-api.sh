#!/bin/bash
# Script Name: resource-api.sh
# Purpose: Manage file attachments in Memos
# Usage: ./resource-api.sh <command> [arguments]

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../load-env.sh"
[[ ! -f "$_LOAD_ENV" ]] && _LOAD_ENV="${HOME}/.claude-homelab/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: load-env.sh not found. Run /homelab-core:setup" >&2; exit 1; }
load_service_credentials "memos" "MEMOS_URL" "MEMOS_API_TOKEN"

# API configuration
API_BASE="${MEMOS_URL}/api/v1"
AUTH_HEADER="Authorization: Bearer ${MEMOS_API_TOKEN}"

# Helper function for API calls
api_call() {
    local method="$1"
    local endpoint="$2"
    local extra_args=("${@:3}")

    curl -s \
        -X "$method" \
        -H "$AUTH_HEADER" \
        "${extra_args[@]}" \
        "${API_BASE}${endpoint}"
}

attachment_id() {
    local name="$1"
    name="${name#attachments/}"
    name="${name#resources/}"
    printf '%s' "$name"
}

# Command: upload
# Usage: resource-api.sh upload <file-path> [--memo-id <id>]
cmd_upload() {
    local file_path="$1"
    shift

    if [[ ! -f "$file_path" ]]; then
        echo '{"error": "File not found", "path": "'"$file_path"'"}' >&2
        exit 1
    fi

    local memo_id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --memo-id)
                memo_id="$2"
                shift 2
                ;;
            *)
                echo '{"error": "Unknown option", "option": "'"$1"'"}' >&2
                exit 1
                ;;
        esac
    done

    local mime_type
    mime_type=$(file --brief --mime-type "$file_path" 2>/dev/null || echo "application/octet-stream")

    local payload
    payload=$(jq -n \
        --arg filename "$(basename "$file_path")" \
        --arg type "$mime_type" \
        --arg content "$(base64 -w0 "$file_path")" \
        --arg memo "$memo_id" \
        '{filename: $filename, type: $type, content: $content}
         + (if $memo != "" then {memo: (if ($memo | startswith("memos/")) then $memo else "memos/" + $memo end)} else {} end)')

    api_call POST "/attachments" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

# Command: list
# Usage: resource-api.sh list [--memo-id <id>]
cmd_list() {
    local memo_id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --memo-id)
                memo_id="$2"
                shift 2
                ;;
            *)
                echo '{"error": "Unknown option", "option": "'"$1"'"}' >&2
                exit 1
                ;;
        esac
    done

    local endpoint="/attachments"
    if [[ -n "$memo_id" ]]; then
        local memo_name="$memo_id"
        [[ "$memo_name" != memos/* ]] && memo_name="memos/${memo_name}"
        endpoint+="?filter=$(printf 'memo == "%s"' "$memo_name" | jq -sRr @uri)"
    fi

    api_call GET "$endpoint"
}

# Command: get
# Usage: resource-api.sh get <attachment-name>
cmd_get() {
    local resource_name="$1"

    if [[ -z "$resource_name" ]]; then
        echo '{"error": "Resource name required"}' >&2
        exit 1
    fi

    api_call GET "/attachments/$(attachment_id "$resource_name")"
}

# Command: delete
# Usage: resource-api.sh delete <attachment-name>
cmd_delete() {
    local resource_name="$1"

    if [[ -z "$resource_name" ]]; then
        echo '{"error": "Resource name required"}' >&2
        exit 1
    fi

    api_call DELETE "/attachments/$(attachment_id "$resource_name")"
}

# Command: download
# Usage: resource-api.sh download <attachment-name> [--output <path>]
cmd_download() {
    local resource_name="$1"
    shift

    if [[ -z "$resource_name" ]]; then
        echo '{"error": "Resource name required"}' >&2
        exit 1
    fi

    local output_path=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output|-o)
                output_path="$2"
                shift 2
                ;;
            *)
                echo '{"error": "Unknown option", "option": "'"$1"'"}' >&2
                exit 1
                ;;
        esac
    done

    # If no output specified, use resource name
    if [[ -z "$output_path" ]]; then
        output_path="$(basename "$resource_name")"
    fi

    api_call GET "/attachments/$(attachment_id "$resource_name")" \
        | jq -r '.content // empty' \
        | base64 -d > "$output_path"

    if [[ -f "$output_path" ]]; then
        echo '{"success": true, "path": "'"$output_path"'", "resource": "'"$resource_name"'"}'
    else
        echo '{"error": "Download failed"}' >&2
        exit 1
    fi
}

# Usage message
usage() {
    cat <<EOF
Usage: $0 <command> [arguments]

Commands:
    upload <file-path> [--memo-id <id>]
        Upload a file as an attachment (optionally attach to memo)

    list [--memo-id <id>]
        List all attachments (optionally filter by memo)

    get <attachment-name>
        Get attachment metadata

    delete <attachment-name>
        Delete an attachment

    download <attachment-name> [--output <path>]
        Download an attachment file

Examples:
    $0 upload document.pdf
    $0 upload screenshot.png --memo-id 123
    $0 list
    $0 list --memo-id 123
    $0 get attachments/abc123
    $0 delete attachments/abc123
    $0 download attachments/abc123 --output /tmp/file.pdf
EOF
}

# Main command dispatcher
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    local command="$1"
    shift

    case "$command" in
        upload)
            cmd_upload "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        get)
            cmd_get "$@"
            ;;
        delete)
            cmd_delete "$@"
            ;;
        download)
            cmd_download "$@"
            ;;
        --help|-h|help)
            usage
            ;;
        *)
            echo '{"error": "Unknown command", "command": "'"$command"'"}' >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
