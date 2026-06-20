# Dendrite Agent Instructions

`CLAUDE.md` is the source of truth for agent memory in this repo. `AGENTS.md`
and `GEMINI.md` must be symlinks to this file.

## Purpose

Dendrite owns the portable Claude Code and Codex plugin marketplace. It carries
plugin sources, skills, MCP config snippets, commands, hooks, scripts, and
OpenAI agent companion files.

The Lab control-plane plugin is the exception: `plugins/labby` stays in
`jmagar/lab` and is referenced from marketplace manifests as a GitHub
subdirectory source.

## Repository Rules

- Do not add `plugins/labby` to this repo.
- Keep `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`
  aligned when adding, renaming, or removing marketplace entries.
- Every skill directory with `SKILL.md` must also include
  `agents/openai.yaml`.
- Plugin manifests live under `.claude-plugin/plugin.json` and
  `.codex-plugin/plugin.json` when both agent runtimes are supported.
- Keep secrets out of the repo. Plugin config hooks may write local config files,
  but committed examples must not contain real credentials.
- Preserve executable bits on scripts and hooks when copying plugin directories.
- Plugin README and CHANGELOG files must be useful, not empty placeholders.
  `plugins/scripts/check-plugin-docs` enforces this as part of `check-all`.

## Long-Lived Branches

- `marketplace-no-mcp` is an intentional long-lived marketplace variant branch,
  not stale cleanup. It keeps the same skill/plugin catalog available while
  removing bundled MCP server registrations for environments where those MCP
  servers are already connected through the Labby gateway. Leave the branch and
  its worktree in place unless Jacob explicitly asks to retire the no-MCP
  marketplace variant.
- Do not merge `marketplace-no-mcp` into `main` by default. `main` is the
  canonical full marketplace for normal users and should keep bundled MCP server
  registrations where a plugin owns them; `marketplace-no-mcp` is Jacob's
  gateway-oriented alternate ref.
- The `.github/workflows/sync-marketplace-no-mcp.yml` workflow keeps
  `marketplace-no-mcp` current after pushes to `main` and on a daily schedule:
  it merges `main`, runs `plugins/scripts/apply-no-mcp-marketplace`,
  validates both marketplace manifests, runs the no-MCP invariant check, and
  pushes the branch only when that produces a change. The transform regenerates
  Gemini manifests, the README inventory, and generated docs as part of its
  deterministic rewrite.
- The `.github/workflows/check-no-mcp-drift.yml` workflow runs
  `plugins/scripts/check-no-mcp-drift --compare-ref` on a schedule and on
  manual dispatch. It compares `origin/marketplace-no-mcp` with `origin/main`
  plus the deterministic no-MCP transform, then smoke-tests marketplace
  installs from both refs.
- `marketplace-no-mcp` should allow GitHub Actions to push sync commits, but
  humans should not casually push, merge, or close it. Direct human writes are
  release-maintenance work and must be followed by
  `plugins/scripts/check-no-mcp-drift --compare-ref`.
- Keep the no-MCP transform deterministic. If a new MCP-backed marketplace entry
  needs the alternate ref, add its plugin name to `NO_MCP_REF_NAMES` in
  `plugins/scripts/apply-no-mcp-marketplace` instead of hand-editing the
  long-lived branch.

## Common Checks

```bash
# No local labby plugin copy.
test ! -e plugins/labby

# Apply and validate the no-MCP marketplace transform locally.
plugins/scripts/apply-no-mcp-marketplace
plugins/scripts/check-all

# Compare origin/marketplace-no-mcp with origin/main plus the no-MCP transform.
plugins/scripts/check-no-mcp-drift --compare-ref

# Smoke Claude, Codex, and Gemini marketplace/extension installs in temp homes.
plugins/scripts/smoke-marketplace-install

# Plugin README and CHANGELOG files must exist and contain useful content.
plugins/scripts/check-plugin-docs

# Claude and Codex marketplace entries must stay aligned by plugin name and
# normalized source target. Local plugins with Claude or Codex manifests must
# also have a sibling gemini-extension.json.
plugins/scripts/check-marketplace-sync

# Validate plugin and marketplace manifests. Claude uses published SchemaStore
# schemas. Codex and Gemini use local docs-derived schemas under plugins/schemas;
# Gemini extensions are also checked with the official `gemini extensions
# validate` command.
plugins/scripts/validate-plugin-schemas

# Print the upstream docs/source files used to maintain local Codex and Gemini
# schemas. Use this before changing plugins/schemas/*.
plugins/scripts/audit-upstream-schema-sources

# Regenerate docs/plugin-matrix.md, docs/configuration-matrix.md,
# docs/marketplace-sources.md, docs/schema-provenance.md, and
# docs/no-mcp-variant.md after changing manifests, config, schemas, or no-MCP
# marketplace rules.
plugins/scripts/generate-docs

# Enable the tracked pre-push hook in a clone.
git config core.hooksPath .githooks

# Every skill has an OpenAI companion file.
for f in $(find plugins -path '*/skills/*/SKILL.md' -type f | sort); do
  dir=${f%/SKILL.md}
  test -f "$dir/agents/openai.yaml" || echo "missing companion: $dir"
done

# Marketplace manifests parse.
jq empty .claude-plugin/marketplace.json
jq empty .agents/plugins/marketplace.json
```
