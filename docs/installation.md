# Installation

Dendrite publishes the default/full marketplace from `main`. Use this when the
agent runtime should install plugin-provided MCP server registrations.

The no-MCP variant is published from `marketplace-no-mcp`. Use it when you want
the skills and plugin metadata without automatically adding MCP servers to the
agent runtime.

## Claude Code

Full/default marketplace:

```bash
claude plugin marketplace add jmagar/dendrite
```

No-MCP variant:

```bash
claude plugin marketplace add 'jmagar/dendrite#marketplace-no-mcp'
```

Claude accepts `owner/repo#ref`, `https://...`, and local paths. Do not use the
unsupported `github:jmagar/dendrite#marketplace-no-mcp` form.

## Codex

Full/default marketplace:

```bash
codex plugin marketplace add jmagar/dendrite
```

No-MCP variant:

```bash
codex plugin marketplace add jmagar/dendrite --ref marketplace-no-mcp
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

For the no-MCP variant, check out the `marketplace-no-mcp` ref first, then
install or link the plugin directory:

```bash
git clone --branch marketplace-no-mcp --depth 1 --filter=blob:none --sparse https://github.com/jmagar/dendrite.git dendrite-no-mcp
cd dendrite-no-mcp
git sparse-checkout set plugins/acp
gemini extensions install plugins/acp --consent --skip-settings
```

Gemini accepts `--ref` for whole-repository extensions, but Dendrite's Gemini
extensions live below `plugins/<name>/`, so installing from a local checkout is
the reliable path.

## Smoke Test

Run the local install smoke before publishing marketplace changes:

```bash
plugins/scripts/smoke-marketplace-install
plugins/scripts/smoke-marketplace-install --ref origin/main
plugins/scripts/smoke-marketplace-install --ref origin/marketplace-no-mcp
```
