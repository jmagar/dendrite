# Axon MCPJam UI Pattern

Use this reference only when validating Axon's MCP-UI dashboard contract.

Expected UI contract:

- UI tool: `axon_status_dashboard`
- UI resource: `ui://axon/status-dashboard`
- MIME type: `text/html;profile=mcp-app`
- Generic routed tool: `axon` should not carry dashboard UI metadata
- Tool call: `axon_status_dashboard` should return `structuredContent` with status payload data

Focused HTTP checks:

```bash
mcpjam server doctor --url http://127.0.0.1:8001/mcp
mcpjam apps conformance --url http://127.0.0.1:8001/mcp
mcpjam tools list --url http://127.0.0.1:8001/mcp
mcpjam resources list --url http://127.0.0.1:8001/mcp
mcpjam resources read --url http://127.0.0.1:8001/mcp --resource-uri ui://axon/status-dashboard
mcpjam tools call --url http://127.0.0.1:8001/mcp --tool-name axon_status_dashboard --tool-args '{}'
```

Focused stdio check:

```bash
mcpjam server doctor --command ./target/debug/axon --args mcp --cwd /home/jmagar/workspace/axon
```
