---
name: zsnoop-mcp
description: Use for ZFS snapshot exploration and recovery through zsnoop-mcp. Triggers include "restore a file from a ZFS snapshot", "when did this file get deleted", "check my zpool health", "compare two snapshots", "grep inside a snapshot", "show snapshot cadence", "list ZFS pools/datasets/snapshots", "find when a file appeared or changed", "fetch a file out of a snapshot to my workstation", and "read a file inside a snapshot". Also use when configuring or troubleshooting the zsnoop MCP server, hosts.toml, SSH or local transport, sudo mode, or restore allowlists.
---

# Zsnoop MCP

Use `zsnoop-mcp` for ZFS snapshot exploration and recovery. The plugin wires the
upstream stdio MCP server as `uvx zsnoop-mcp`; the server reads hosts from
`$ZSNOOP_CONFIG`, `$XDG_CONFIG_HOME/zsnoop-mcp/hosts.toml`, or
`~/.config/zsnoop-mcp/hosts.toml`.

## First Steps

1. Call `list_hosts` before host-specific work.
2. For health or inventory questions, call `list_pools`, `pool_status`, then
   `list_datasets` or `list_snapshots`.
3. For file recovery, narrow by host, dataset, path, and time window before
   reading or fetching content.
4. For restore requests, confirm the user wants to write to the live server and
   verify the host has `allow_restore = true` plus a non-empty `restore_paths`
   allowlist. Restore tools are the only mutating zsnoop tools.

## Workflow Map

- Pool health: `list_pools` -> `pool_status`.
- Snapshot coverage: `list_snapshots` -> `snapshot_cadence`.
- What changed: `diff_snapshots`, `file_diff`, `versions_of`, or
  `file_history`.
- Find deleted or missing files: `snapshots_containing`, `last_appearance`,
  `find_deleted`.
- Inspect content: `list_dir`, `read_file`, `find_files`, `content_grep`,
  `checksum_file`.
- Copy out to this workstation: `fetch_file` or `fetch_dir`.
- Restore on the ZFS host: `restore_file` or `restore_dir` only after explicit
  confirmation and allowlist verification.

Read `references/tools.md` for detailed tool selection, limits, and path
rules. Read `references/configuration.md` when setting up or debugging
`hosts.toml`, SSH, sudo mode, local transport, or restore allowlists.

## Guardrails

- Treat snapshot paths as relative to the snapshot root; leading `/` is okay,
  but `..` is rejected.
- Prefer bounded searches with `after`, `before`, `dataset`, and
  `max_results` instead of broad unfiltered calls.
- Do not ask zsnoop to delete snapshots, destroy datasets, mount filesystems, or
  change pools; it does not expose those operations.
- Do not use restore tools unless the user explicitly asks to restore to the
  live host. For safer recovery, prefer `fetch_file`/`fetch_dir` to a local path.
- For root-owned files, expect host config to require `sudo = true` and
  passwordless sudo on the remote.
