---
name: mcporter
description: Use when the user mentions mcporter, says "test an MCP server", "smoke-test these tools", "automate MCP testing", "call a tool from the shell", "list MCP tools", "exercise the gateway tools", or asks for a script that hits MCP endpoints. Covers using mcporter to discover, inspect, and call MCP servers from the shell, and to write repeatable regression or smoke-test scripts. Not for designing new MCP servers, writing server-side handlers, or generic API testing unrelated to MCP.
argument-hint: "[server] [tool]"
---

## Context

- Argument: $ARGUMENTS
- CWD: !`pwd`
- mcporter: !`command -v mcporter >/dev/null && mcporter --version 2>/dev/null || echo "not installed (npm i -g mcporter)"`
- Configured servers: !`mcporter list --json 2>/dev/null | jq -r '.servers[] | "\(.status)\t\(.name)"' 2>/dev/null | head -20 || echo "none / mcporter unavailable"`

# mcporter — MCP CLI & test scripting

`mcporter` is a shell client for the Model Context Protocol. Use it to list servers, inspect tool schemas, call tools, and drive scripted regression tests over the wire — without writing a TypeScript client.

Auto-loads servers from `./config/mcporter.json` plus editor imports (Cursor, Claude Code, Codex, etc.), so most named servers in the user's environment already work without setup.

## Core verbs

```bash
mcporter list                          # all configured servers (status only)
mcporter list <server> --schema        # tool docs for one server
mcporter list <server> --schema --all-parameters --json
mcporter call <server>.<tool> k=v ...  # invoke a tool
mcporter call <server>.<tool> --args '{"k":"v"}'      # JSON payload
mcporter call <server>.<tool> --output text           # assertion-friendly text
mcporter resource <server>             # list resources
mcporter resource <server> <uri>        # read a resource
mcporter auth <server>                 # OAuth handshake only (no listing)
mcporter config doctor                 # validate all configs
```

Tool selectors are `server.tool`. The server argument is a configured server name or a full `https://host/mcp` URL.

## Calling resources & prompts

Use `mcporter resource` for MCP resources:

```bash
mcporter call <server>.<tool> k=v               # tool call
mcporter resource <server>                      # list resources
mcporter resource <server> <resource-uri>       # resource read
mcporter call <server> --tool <prompt-name> ... # prompt fetch
```

If the schema isn't obvious, run `mcporter list <server> --schema --all-parameters` first — guessing arg names against the wrong shape is the #1 wasted call.

## Argument forms (pick one, don't mix)

| Form | When |
|---|---|
| `key=value` / `key:value` | Flat scalar args, fast for shell use |
| `--args '{...}'` | Nested objects, arrays, anything with quoting pain |
| `'server.tool(key: "value", n: 1)'` | Function-call syntax when you want it self-documenting in a script |

`--output text\|markdown\|json\|raw` controls formatting. Use `text` for
scripted assertions and `raw` only when inspecting the MCP envelope.

## Ad-hoc servers (one-shot, no config edit)

```bash
mcporter list --http-url https://host/mcp --schema
mcporter call --stdio 'bun run ./server.ts' my_tool arg=1
mcporter list https://host/mcp                    # bare URL = HTTP
mcporter call --stdio 'node srv.js' --env API_KEY=$KEY tool arg=1
```

Persist a working ad-hoc definition with `--persist ./config/mcporter.json --yes`.

## Generating a standalone CLI

When the user wants a sharable, schema-validated wrapper rather than a shell script, prefer `mcporter generate-cli`:

```bash
mcporter generate-cli --server <name> --compile ./bin/<name>-cli
mcporter generate-cli --command 'npx -y @org/server' --name my-cli --compile ./bin/my-cli
```

The generated CLI bundles the tool schemas at build time, so every call is type-checked locally before it leaves the process. Inspect a generated binary with `mcporter inspect-cli ./bin/my-cli`.

## Writing a test harness

The goal: prove each tool returns the *right* thing for a known input — and catch breakage *before* sending the call when possible. Keep the script readable.

The template at `scripts/smoke.sh` (in this skill folder) does three things `mcporter` doesn't:

1. **Schema preflight** — pulls `inputSchema` once and rejects any case whose `args` are missing a required key. Catches typos *locally*, no network call.
2. **Robust error detection** — treats transport failure, wrapper warnings, MCP protocol errors (`MCP error -32xxx`), and tool-level `isError: true` envelopes as failures (each tagged differently in the report).
3. **String + regex assertions** — see below. Avoids depending on `mcporter call --output json`, which currently emits Node `util.inspect` format (not parseable JSON) on most servers.

Each `CASES=()` row is `"label|args|assertion"` — a tool name (or `ui://` resource URI) as the label, the `mcporter call` args, and one of five assertion forms (empty=liveness, `contains:`, `regex:`, `jq:`, `error:`). Bootstrap a server's case list with `./smoke.sh --init <server>`, then fill in real values:

```bash
./smoke.sh --init lab > cases.sh.fragment   # skeleton CASES=() with TODO args
# paste tools into smoke.sh, replace each TODO with a value + assertion, run
```

```bash
# example CASES=() rows
"search|q=hello|contains: result"           # tool call + substring assert
"ui://server/status||contains: ok"          # resource read (empty args)
```

The full case-format / assertion-form tables, helper modes, env flags (`TIMEOUT_MS`, `VERBOSE`, `NO_PREFLIGHT`), and the `set -e` snippet traps are in [`references/tips-gotchas.md`](references/tips-gotchas.md).

Note: don't assert on `--output json` — it emits Node `util.inspect` format (not parseable JSON) on most servers. The harness uses `--output text` for assertions and `--output raw` only to inspect the `isError` envelope.

## Common failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `Unknown MCP server 'X'` | Name typo or import not picked up | `mcporter list` to see actual names; `mcporter config list --verbose` for sources |
| Tool call hangs ~30s then `tools unavailable` | Stdio binary missing (`ENOENT`) | Build / install the server binary; check the `transport` field in `--json` |
| `SSE error: Non-200 status code` | HTTP server down or auth expired | `mcporter auth <server> --reset` or check the URL |
| Args rejected with cryptic schema error | Flat `k=v` against a nested schema | Switch to `--args '{...}'` |
| `OAuth timeout` | Browser flow didn't complete in time | `--oauth-timeout 180000` and rerun `mcporter auth` |

## Quick reference

```bash
mcporter list --json | jq '.servers[] | {name, status}'      # health snapshot
mcporter list <s> --schema --json | jq '.tools[].name'       # tool names only
mcporter call <s>.<t> --args "$(cat payload.json)" --output text
mcporter generate-cli --server <s> --compile ./bin/<s>       # ship a binary
```

## What NOT to do

- Don't paste secrets as `key=value` on the command line — use `--env KEY=$VAR` for stdio servers, env-injection for HTTP.
- Don't write a Node/TS client when `mcporter call` + a shell loop will do.
- Don't rely on `--output json` for machine-parseable output in scripts — it emits Node util.inspect format, not valid JSON. Use `--output text` for assertions and `--output raw` for envelope inspection.
- Don't run smoke scripts against production data without checking which side-effects each tool has; mcporter is just a transport, it has no idea what's destructive.
- Don't commit `./config/mcporter.json` with personal tokens; use editor-imports or `--env`.

## References

- [`references/cli-commands.md`](references/cli-commands.md) — full flag tables for every subcommand (`list`, `call`, `auth`, `generate-cli`, `emit-ts`, `config`, `daemon`). Load when you need exact flag semantics beyond the quick reference above.
- [`references/configuration.md`](references/configuration.md) — `mcporter.json` format, config resolution order, `allowedTools`/`blockedTools`, OAuth cache, and all environment variables.
- [`references/tips-gotchas.md`](references/tips-gotchas.md) — real footguns in rough order of frequency: `--help` coverage gaps, function-call quoting, `generate-cli` input exclusivity, Bun requirement for `--compile`, daemon limitations, and `string`-field coercion. Also holds the full `smoke.sh` case-format/assertion tables, helper modes, env flags, and `set -e` snippet traps.
- [`references/typescript-api.md`](references/typescript-api.md) — `callOnce()`, `createRuntime()`, `createServerProxy()` API surface and when to use each. Load when the user wants a TypeScript client rather than a shell script.
- [`scripts/smoke.sh`](scripts/smoke.sh) — the test harness template. Copy and populate `CASES=()` for a new server.
