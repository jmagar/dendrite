# zsnoop-mcp Configuration

## Local Requirements

- Python 3.11+
- `uv` for the plugin's `uvx zsnoop-mcp` command
- OpenSSH client
- SSH agent/key access to each remote ZFS host

## Config Discovery

`zsnoop-mcp` loads host config from:

1. `$ZSNOOP_CONFIG`
2. `$XDG_CONFIG_HOME/zsnoop-mcp/hosts.toml`
3. `~/.config/zsnoop-mcp/hosts.toml`

Minimal remote host:

```toml
[hosts.nas]
ssh_target = "nas.example.com"
agent_mode = "bootstrap"
sudo = false
pools = ["rpool"]
```

Minimal local host, useful when the MCP client runs on the ZFS machine:

```toml
[hosts.this-box]
transport = "local"
agent_mode = "bootstrap"
sudo = false
```

## Host Fields

- `transport`: `ssh` or `local`; default `ssh`.
- `ssh_target`: required for SSH transport, passed to `ssh`.
- `agent_mode`: `bootstrap` or `preinstalled`; default `bootstrap`.
- `agent_path`: required for `preinstalled`.
- `sudo`: run the remote/local agent under sudo; requires passwordless sudo.
- `remote_python`: interpreter for bootstrap mode; default `python3`.
- `ssh_options`: extra SSH args, for example `["-o", "ConnectTimeout=5"]`.
- `pools`: optional hints for the LLM; live pool discovery still uses tools.
- `allow_restore`: opt in to writable restore tools; default `false`.
- `restore_paths`: absolute path prefixes restores may write under; required
  and non-empty when `allow_restore = true`.

## Remote Requirements

Each remote ZFS host needs Python 3.11+, OpenSSH server, and the `zfs` CLI. In
default user mode, grant only the ZFS `diff` permission for pools that need
snapshot diffs:

```bash
sudo zfs allow -u "$USER" diff rpool
```

Use `sudo = true` only when the user needs to read or restore root-owned files.
Sudo mode needs passwordless sudo for the agent command.

## Restore Allowlist

Restore is disabled by default. To enable it for one host:

```toml
[hosts.nas]
ssh_target = "nas.example.com"
agent_mode = "bootstrap"
allow_restore = true
restore_paths = ["/srv/", "/home/alice/"]
```

`restore_paths` must contain absolute prefixes. Zsnoop always refuses restores
under `/proc/`, `/sys/`, `/dev/`, or any `.zfs/snapshot` tree.

## Troubleshooting

- Missing config: create `hosts.toml` or set `ZSNOOP_CONFIG`.
- Publickey failures: ensure the MCP client environment exposes SSH agent state
  such as `SSH_AUTH_SOCK`.
- `zfs diff` permission errors in user mode: grant delegated `diff` permission
  for the relevant pool or use sudo mode intentionally.
- Root-owned snapshot reads fail: configure `sudo = true` and passwordless sudo.
- Restore refuses: confirm `allow_restore = true`, `restore_paths` is non-empty,
  and the target path canonicalizes under an allowed prefix.
