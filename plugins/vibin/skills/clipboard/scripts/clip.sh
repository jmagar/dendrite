#!/usr/bin/env bash
# Push text to a remote Windows machine's clipboard.
#
# Routing:
#   - ASCII single-line:  NirCmd clipboard set (fastest, requires nircmd.exe)
#   - everything else:    PowerShell Set-Clipboard (full Unicode incl. emoji, no nircmd needed)
#
# Falls back to PS-only mode if nircmd isn't present on the target.

set -euo pipefail

HOST="${CLIPBOARD_HOST:-${NIRCMD_HOST:-steamy-wsl}}"
NIRCMD="${CLIPBOARD_NIRCMD:-${NIRCMD_PATH:-/mnt/c/tools/nircmd/nircmd.exe}}"
PS="${CLIPBOARD_POWERSHELL:-/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe}"
TMP_DIR="${CLIPBOARD_TMP_DIR:-/mnt/c/Users/Docker/AppData/Local/Temp}"

if [[ $# -eq 0 ]]; then
  echo "usage: clip.sh <text> | clip.sh -" >&2
  exit 2
fi

if [[ "$1" == "-" ]]; then
  text=$(cat)
else
  text="$*"
fi

is_simple=1
LC_ALL=C grep -qP '[^\x00-\x7F]' <<<"$text" 2>/dev/null && is_simple=0
[[ "$text" == *$'\n'* ]] && is_simple=0
# Fail closed on shell-active chars — they'd be interpreted by the remote shell before NirCmd sees them
case "$text" in
  *[\$\"\`\\]*) is_simple=0 ;;
esac

if [[ "$is_simple" == "1" ]]; then
  have_nircmd=0
  # shellcheck disable=SC2029 # Intentional local expansion into the remote test command.
  ssh "$HOST" "test -f '$NIRCMD'" 2>/dev/null && have_nircmd=1
  if [[ "$have_nircmd" == "1" ]]; then
    # shellcheck disable=SC2029 # Intentional local expansion into the remote NirCmd command.
    ssh "$HOST" "$NIRCMD clipboard set \"$(printf '%s' "$text" | sed 's/"/\\"/g')\""
    echo "pushed $(printf '%s' "$text" | wc -c) bytes (ascii via nircmd)"
    exit 0
  fi
fi
# PowerShell temp-file path: lossless, no inline-quoting hazard
remote_posix="$TMP_DIR/clip-$$-$(date +%s).txt"
# /mnt/<drive> → <drive>:; works for any mounted drive letter, not just C
remote_win=$(printf '%s' "$remote_posix" | sed -E 's|^/mnt/([a-z])|\U\1:|; s|/|\\\\|g')
# shellcheck disable=SC2029 # Intentional local expansion into the remote temp-file path.
printf '%s' "$text" | ssh "$HOST" "cat > '$remote_posix'"
trap 'ssh "$HOST" "rm -f '\''$remote_posix'\''" >/dev/null 2>&1 || true' EXIT
# shellcheck disable=SC2029 # Intentional local expansion into the remote PowerShell command.
ssh "$HOST" "$PS -NoProfile -Command \"Set-Clipboard -Value (Get-Content -Raw -Encoding UTF8 '$remote_win')\""
trap - EXIT
# shellcheck disable=SC2029 # Intentional local expansion into the remote cleanup command.
ssh "$HOST" "rm -f '$remote_posix'"
echo "pushed $(printf '%s' "$text" | wc -c) bytes (unicode via powershell)"
