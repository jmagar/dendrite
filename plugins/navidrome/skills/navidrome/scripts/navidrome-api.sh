#!/usr/bin/env bash
# Navidrome/Subsonic API helper.
# Usage: navidrome-api.sh <command> [args...]

set -euo pipefail

load_config() {
  local config="${NAVIDROME_ENV_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/lab-navidrome/config.env}"
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

  : "${NAVIDROME_URL:?set NAVIDROME_URL in plugin settings or ~/.lab/.env}"
  : "${NAVIDROME_USERNAME:?set NAVIDROME_USERNAME in plugin settings or ~/.lab/.env}"
  : "${NAVIDROME_PASSWORD:?set NAVIDROME_PASSWORD in plugin settings or ~/.lab/.env}"
  NAVIDROME_URL="${NAVIDROME_URL%/}"
}

subsonic() {
  local endpoint="$1"
  shift
  local salt token
  salt="$(openssl rand -hex 8)"
  token="$(printf '%s%s' "$NAVIDROME_PASSWORD" "$salt" | md5sum | cut -d' ' -f1)"
  curl -sS --get "${NAVIDROME_URL}/rest/${endpoint}.view" \
    --data-urlencode "u=${NAVIDROME_USERNAME}" \
    --data-urlencode "t=${token}" \
    --data-urlencode "s=${salt}" \
    --data-urlencode "v=1.16.1" \
    --data-urlencode "c=lab" \
    --data-urlencode "f=json" \
    "$@"
}

usage() {
  cat <<'EOF'
Usage: navidrome-api.sh <command> [args...]

Commands:
  ping                         Health/auth check
  artists                      List artists
  albums [type] [size]         List albums, default newest 20
  album <id>                   Album details and tracks
  artist <id>                  Artist details and albums
  search <query>               Search artists, albums, and songs
  playlists                    List playlists
  playlist <id>                Playlist details
  now-playing                  Active streams
  starred                      Starred artists, albums, and songs
  scan-status                  Library scan status
EOF
}

cmd="${1:-help}"
shift || true
case "$cmd" in
  help|-h|--help) usage; exit 0 ;;
esac
load_config

case "$cmd" in
  ping) subsonic ping ;;
  artists) subsonic getArtists ;;
  albums)
    type="${1:-newest}"
    size="${2:-20}"
    subsonic getAlbumList2 --data-urlencode "type=${type}" --data-urlencode "size=${size}"
    ;;
  album)
    id="${1:?album id required}"
    subsonic getAlbum --data-urlencode "id=${id}"
    ;;
  artist)
    id="${1:?artist id required}"
    subsonic getArtist --data-urlencode "id=${id}"
    ;;
  search)
    query="${1:?query required}"
    subsonic search3 --data-urlencode "query=${query}"
    ;;
  playlists) subsonic getPlaylists ;;
  playlist)
    id="${1:?playlist id required}"
    subsonic getPlaylist --data-urlencode "id=${id}"
    ;;
  now-playing) subsonic getNowPlaying ;;
  starred) subsonic getStarred2 ;;
  scan-status) subsonic getScanStatus ;;
  *) usage >&2; exit 2 ;;
esac
