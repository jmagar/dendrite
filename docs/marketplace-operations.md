# Marketplace Operations

Use this runbook when adding, removing, renaming, or updating marketplace
entries.

## Source Model

- `main` is the full/default marketplace for normal users. It may include local
  `.mcp.json` files and Gemini `mcpServers` entries.
- `marketplace-no-mcp` is generated from `main` for installs that do not want
  bundled MCP server registrations. It keeps skills/plugins while removing
  bundled MCP config.
- External plugin sources should be referenced from the marketplace manifests
  instead of copied into this repository.

## Add Or Update A Local Plugin

1. Put source under `plugins/<name>/`.
2. Add or update `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`.
3. Add or update `gemini-extension.json`.
4. Ensure every `skills/*/SKILL.md` has `agents/openai.yaml`.
5. Add useful `README.md` and `CHANGELOG.md` files.
6. Add matching entries to `.claude-plugin/marketplace.json` and
   `.agents/plugins/marketplace.json`.
7. Run:

```bash
plugins/scripts/generate-gemini-extensions
plugins/scripts/generate-readme-inventory
plugins/scripts/generate-docs
plugins/scripts/check-all
plugins/scripts/smoke-marketplace-install
```

## Add Or Update A Curated Remote Plugin

1. Prefer `git-subdir` when the plugin lives below a repository subdirectory.
2. Pin external third-party plugins by `sha` when practical.
3. Keep Claude and Codex entries normalized to the same repo/path/ref/sha.
4. Update `docs/marketplace-sources.md` by running `plugins/scripts/generate-docs`.

## MCP-Backed Entries

For the full marketplace, keep MCP registrations where they are useful for a
normal user. For the no-MCP variant, add the plugin name to `NO_MCP_REF_NAMES`
in `plugins/scripts/apply-no-mcp-marketplace` only when that remote plugin also
has a `marketplace-no-mcp` ref.

Never hand-edit `marketplace-no-mcp` as the primary fix. Change `main` and the
transform, then let `.github/workflows/sync-marketplace-no-mcp.yml` publish the
derived branch.

## Remove A Plugin

1. Remove both marketplace entries.
2. Remove the local plugin directory if Dendrite owns it.
3. Remove its name from `NO_MCP_REF_NAMES` if present.
4. Regenerate docs and run the full checks.

## Required Checks

```bash
plugins/scripts/check-all
plugins/scripts/check-no-mcp-drift --compare-ref
plugins/scripts/smoke-marketplace-install
```
