---
name: scrutiny
description: "Use when inspecting Scrutiny SMART monitoring data for hard drive or SSD health, disk failures, SMART attributes, drive temperatures, and storage device status. Trigger on requests such as \"check my drives\", \"are any disks failing\", \"show SMART errors\", \"what's the temperature on my drives\", \"is drive X healthy\", or \"check Scrutiny\"."
---

# Scrutiny

SMART drive-health monitoring. Talk to Scrutiny directly over its web API,
served under `/api`.

## How to call it

Configure `scrutiny_url` in Claude plugin settings or Gemini extension settings.
The SessionStart/ConfigChange hook writes
`${XDG_CONFIG_HOME:-~/.config}/lab-scrutiny/config.env` with mode `600`.
Use an existing `SCRUTINY_URL` environment variable, or load it from generated
plugin config with legacy Lab env as a fallback:

```bash
source "${XDG_CONFIG_HOME:-$HOME/.config}/lab-scrutiny/config.env" 2>/dev/null || source ~/.lab/.env

: "${SCRUTINY_URL:?Set SCRUTINY_URL to the Scrutiny base URL}"
```

Scrutiny's web API is unauthenticated by default.

Use the base URL without a trailing `/api`; the examples below append `/api`.

## Common operations

| Intent | Request |
|---|---|
| Health | `curl -sS "$SCRUTINY_URL/api/health" -w '\nHTTP %{http_code}\n'` |
| Dashboard summary (all devices) | `curl -sS "$SCRUTINY_URL/api/summary"` |
| List monitored devices | `curl -sS "$SCRUTINY_URL/api/summary" \| python3 -c 'import sys,json;print(*json.load(sys.stdin)["data"]["summary"].keys(),sep="\n")'` |
| Device SMART details | `curl -sS "$SCRUTINY_URL/api/device/<wwn>/details"` |
| Temperature history | `curl -sS "$SCRUTINY_URL/api/summary/temp"` |

The device list comes from the `summary` payload — `GET /api/summary` returns `data.summary` keyed by device WWN, each with its latest SMART status. Use a WWN from there for the `device/<wwn>/details` call.

## Configuration

Verify connectivity before interpreting health output:

```bash
curl -sS "$SCRUTINY_URL/api/health" -w '\nHTTP %{http_code}\n'
```

## When NOT to use this skill

- The user is asking about a different homelab service — load that service's skill instead.
- The user wants raw `smartctl` output on a specific host — that's an SSH/shell task, not Scrutiny.
