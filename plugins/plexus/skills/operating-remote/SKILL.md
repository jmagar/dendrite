---
name: operating-remote
description: This skill should be used when the user asks to inspect, troubleshoot, change, SSH into, or operate a named remote host that has a Plexus `REMOTE.md` profile, such as squirts, dookie, steamy, or another homelab device. Before changing state, load durable host memory and live context with `remote-context.py <host>`. This is host-scoped operational memory for remote machines.
argument-hint: <host> [--json] [--no-probe]
---

# Operating Remote Hosts With Plexus

Use this skill when the task is about a named remote machine and Plexus has a
matching `REMOTE.md` profile. Profiles live in the Plexus data directory:
`$PLEXUS_DATA_DIR`, `$CLAUDE_PLUGIN_DATA`, `$CODEX_PLUGIN_DATA`, or `~/.plexus`
as a fallback.

## Required First Step

Identify the host from the user's request and run the context loader before
making changes:

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-${CODEX_PLUGIN_ROOT:-plugins/plexus}}/scripts/remote-context.py" <host>
```

Use `--no-probe` only when the user asks for an offline plan or when SSH/live
tools are unavailable. Treat `<host>` as a profile name, not a shell fragment;
use only the exact host token from the request or from known Plexus profiles.

## How To Use The Context

Treat `REMOTE.md` as durable host memory: roles, important paths, access
patterns, guardrails, and known quirks. Treat live probe output as the current
state. If the two disagree, call out the discrepancy and prefer observed live
state for operational decisions.

## Operating Rules

- Use non-interactive SSH: `ssh -o BatchMode=yes <host> <command>`.
- Inspect before changing state: uptime, disk, memory, failed units, Docker
  containers, and recent syslog entries.
- Prefer host-specific guardrails in `REMOTE.md` over generic assumptions.
- For service work, capture enough before/after evidence to prove the change.
- If a task touches a reverse proxy, certificate, firewall, storage pool, or
  auth boundary, validate first and use a rollback path.

## Related Context

Plexus pairs well with `cortex:cortex-logs`: recent logs and AI/session history
explain what changed before the current request. It also composes with
service-specific skills like `tailscale`, `unraid`, `create-swag-config`, and
`homelab-map`.
