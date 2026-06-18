---
name: mcpjam-ui-testing
description: "This skill should be used when the user wants to validate an MCP-UI or MCP Apps implementation — checking widget rendering in the Inspector, verifying ui:// resource contracts, testing structuredContent, or running MCP Apps conformance checks. Triggers include: \"why isn't my MCP widget rendering\", \"test my MCP-UI implementation\", \"check if my tool passes MCP Apps conformance\", \"verify the ui:// resource contract\", \"debug my Inspector view\". Does not apply for general MCP tool smoke-testing (use mcporter for that)."
---

# MCPJam UI Testing

Use this skill to prove an MCP-UI surface works at the protocol and rendered-widget layers. Prefer MCPJam CLI for deterministic checks, then MCPJam Inspector for visual/rendering behavior.

## Workflow

For repeatable CLI validation, use
`scripts/mcpjam-ui-check.sh --url <mcp-url> [--resource-uri ui://...] [--tool-name <name>]`.
The helper runs server doctor, app conformance, tools list, resources list, and
optional resource/tool/render checks while passing target/auth flags through to
`mcpjam`.

1. Identify the target transport.
   - HTTP: use `--url http://host:port/mcp`.
   - stdio: use `--command <binary> --args <args...> --cwd <repo>`.
   - If the server requires auth, use the installed CLI's shared connection flags such as
     `--access-token`, `--oauth-access-token`, `--credentials-file`, or repeatable `--header
     "Key: Value"`; run `mcpjam <command> --help` before guessing.

2. Run server health first.
   - `mcpjam server doctor ...`
   - Fix connectivity, auth, protocol version, or transport errors before testing UI.

3. Run app conformance.
   - `mcpjam apps conformance ...`
   - Treat failures here as contract bugs unless the CLI output clearly indicates an unsupported host/transport feature.

4. Manually verify the wire shape.
   - `mcpjam tools list ...`
   - UI-capable tools must advertise `_meta.ui.resourceUri`; MCPJam may also surface legacy
     `_meta["ui/resourceUri"]` or OpenAI `openai/outputTemplate` metadata for compatibility, but new
     MCP Apps should use `_meta.ui.resourceUri`.
   - The URI should be stable and use `ui://...`.
   - Non-UI catch-all tools should not advertise UI metadata unless every call should render that UI.

5. Verify resource discovery and content.
   - `mcpjam resources list ...`
   - `mcpjam resources read --resource-uri ui://... ...`
   - The UI resource must use `text/html;profile=mcp-app`.
   - `resources/read` should return exactly one HTML text/blob payload for the referenced UI URI.
   - Resource `_meta.ui` should declare CSP/permissions when the app needs them; prefer locked-down empty arrays/objects for self-contained widgets.

6. Verify the tool call payload.
   - `mcpjam tools call --tool-name <tool> --tool-args '{}' ...`
   - Prefer `structuredContent` for data the widget consumes.
   - Keep model-readable `content` useful, but do not make the widget scrape human text when structured JSON is available.

7. Test rendering in Inspector.
   - Start or open Inspector with `mcpjam inspector start` or `mcpjam inspector open`.
   - Then call the UI tool with the CLI's UI rendering flag if available
     (`mcpjam tools call ... --ui --require-render`).
   - A pass means the JSON output includes `inspectorRender.status == "rendered"`, not merely that
     the tool call exits 0 or `resources/read` returns HTML. If render is skipped, follow
     `inspectorRender.remediation` before retesting.

## Project Patterns

Keep this core workflow generic. Load
[`references/axon.md`](references/axon.md) only when specifically validating
Axon's MCP-UI dashboard contract.

## Debugging Failures

- `tools/list` missing `_meta.ui.resourceUri`: fix tool metadata, not resource serving.
- `resources/list` missing the URI: register the UI resource.
- `resources/read` wrong MIME: set `text/html;profile=mcp-app` on the returned resource contents.
- Conformance passes but UI does not render: use Inspector and check HTML runtime errors, sandbox/CSP metadata, and whether the tool result contains structured data.
- Inspector skipped/no active client: open/start Inspector first, then rerun `tools call --ui`.
- `tools call --ui` exits 0 but no widget is visible: inspect `inspectorRender.status`; require
  `rendered` or rerun with `--require-render` so skipped renders fail the check.
- HTTP `406` or SSE errors: ensure the client sends `Accept: application/json, text/event-stream`; MCPJam normally handles this.
- Auth errors: verify bearer/OAuth config before debugging UI.

## References

Load [references/commands.md](references/commands.md) when exact MCPJam commands or expected outputs are needed.
