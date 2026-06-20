# Installation

Dendrite publishes the default/full marketplace from `main`. Use this when the
agent runtime should install plugin-provided MCP server registrations.

Jacob's personal no-MCP variant is published from `marketplace-no-mcp`. Use that
only in environments where the same MCP servers are already connected through an
external gateway, such as Labby, and duplicate plugin MCP registrations would be
noise.

## Claude Code

Full/default marketplace:

```bash
claude plugin marketplace add jmagar/dendrite --sparse .claude-plugin plugins
```

No-MCP variant:

```bash
claude plugin marketplace add 'jmagar/dendrite#marketplace-no-mcp' --sparse .claude-plugin plugins
```

Claude accepts `owner/repo#ref`, `https://...`, and local paths. Do not use the
unsupported `github:jmagar/dendrite#marketplace-no-mcp` form.

## Codex

Full/default marketplace:

```bash
codex plugin marketplace add jmagar/dendrite --sparse .agents/plugins --sparse plugins
```

No-MCP variant:

```bash
codex plugin marketplace add jmagar/dendrite --ref marketplace-no-mcp --sparse .agents/plugins --sparse plugins
```

Install a plugin after adding the marketplace:

```bash
codex plugin add acp@dendrite
codex plugin add acp@dendrite-no-mcp
```

## Gemini

Gemini does not install a Dendrite marketplace as a single marketplace catalog.
Install or link individual plugin directories that contain `gemini-extension.json`:

```bash
gemini extensions install plugins/acp --consent --skip-settings
gemini extensions link plugins/acp
gemini extensions validate plugins/acp
```

## Smoke Test

Run the local install smoke before publishing marketplace changes:

```bash
plugins/scripts/smoke-marketplace-install
plugins/scripts/smoke-marketplace-install --ref origin/main
plugins/scripts/smoke-marketplace-install --ref origin/marketplace-no-mcp
```
