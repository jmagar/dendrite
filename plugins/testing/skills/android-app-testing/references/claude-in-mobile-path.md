# Optional path: claude-in-mobile via the Lab gateway

The **primary** android-app-testing path is direct local adb (`scripts/androidtest.sh`) — it needs
nothing but the host SDK + a running emulator and is fully validated. This file documents the
**optional** richer path through the `claude-in-mobile` MCP server and how to recover common gateway
ADB visibility failures.

## What it adds
`claude-in-mobile` (TypeScript MCP, by AlexGladkov) wraps adb with higher-level, agent-friendly
actions and **semantic locators** — tap by `text`/`id`/`index` against a parsed accessibility tree,
screenshot compression/diffing, an `autopilot` BFS/DFS crawler, visual-regression and a11y-audit
tools. Nice for exhaustive mapping; not required for a solid test pass.

## Tool surface (upstream names + params)
Reached as upstream `claude-in-mobile` on the Lab gateway. Action-routed meta-tools:
- `device` — `list` / `set_target {device}` / `get_target` / `enable_module`
- `app` — `launch {package}` / `stop` / `install` / `list`
- `input` — `tap`/`double_tap`/`long_press` (coords or `text`/`id`/`label`/`index`), `swipe {direction}`, `text`
- `screen` — `capture` (compression/diff), `annotate`
- `ui` — `tree` (a11y tree), `find`, `find_tap`
- `system` — `shell`, `logs`, clipboard, permissions, files
- `flow` — `batch` / `run` / `parallel` (multi-step automation)

## How it's invoked here
Through the Lab gateway. In a Code Mode session:
```js
async () => await codemode.claude_in_mobile.device({ action: "list" })
```
Search the gateway catalog first if the helper namespace is different, then call the discovered
tool id with `callTool`. Outside Code Mode the same upstream may appear as direct MCP tools.

## ADB visibility recovery
The gateway can be healthy while Android targets are not visible yet. Distinguish "MCP server is
up" from "device is attached and ADB is reachable" before declaring the path blocked.

1. Confirm the upstream exists: `labby gateway list | rg -i 'claude-in-mobile|mobile'`.
2. Ask the upstream what it sees:
   `labby gateway code exec --json --code 'async () => await codemode.claude_in_mobile.device({ action: "list" })'`.
3. If the error mentions a Docker bridge ADB endpoint such as `172.19.0.1:5037`, restart host ADB
   with remote binding: `adb kill-server && adb -a start-server`.
4. If no target is attached, boot an emulator with the direct adb driver, then rerun the device list.
5. If the server reports `ADB_NOT_INSTALLED`, the gateway runtime still needs `adb` or `ADB_PATH`
   configured; use the direct adb path for the test run and fix the gateway separately.

When recovery is slow or uncertain, use the direct adb path (`scripts/androidtest.sh`). It covers the
full test loop.
