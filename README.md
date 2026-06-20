# Dendrite

Dendrite is the Claude Code, Codex, and Gemini marketplace home for agent
plugins, skills, MCP integrations, hooks, commands, and OpenAI agent companion
files.

It is split out from `jmagar/lab` so the Lab control plane can stay focused on
the `labby` runtime while the agent capability catalog can evolve as its own
public repo.

## Marketplace Files

- `.claude-plugin/marketplace.json`: Claude Code marketplace manifest.
- `.agents/plugins/marketplace.json`: Codex/OpenAI agent marketplace manifest.
- `plugins/*/gemini-extension.json`: Gemini CLI extension manifests for local
  extension installs.
- `plugins/`: local plugin sources carried by this repo.

`plugins/labby` intentionally stays in `jmagar/lab`. The marketplace still
publishes `labby` as an external GitHub subdirectory source:
`https://github.com/jmagar/lab.git`, path `plugins/labby`.

## Marketplace Variants

`main` is the canonical full marketplace branch. It may include plugin metadata
for MCP-backed plugins when those plugins own or bootstrap their MCP server
configuration. This is the default for normal users.

`marketplace-no-mcp` is an intentional long-lived alternate ref for installs
where MCP servers are already registered through the Labby gateway. That branch
keeps the skills and plugin entries available, but strips bundled MCP server
registrations so installing the marketplace does not duplicate servers already
provided by the gateway. This exists for Jacob's gateway-based setup; do not
assume other users operate that way. Treat it as an active release variant, not
stale branch cleanup.

The no-MCP branch is synchronized from `main` by
`.github/workflows/sync-marketplace-no-mcp.yml`. On every push to `main` and on
a daily schedule, the workflow merges `main` into `marketplace-no-mcp`, runs
`plugins/scripts/apply-no-mcp-marketplace`, validates both marketplace
manifests, runs the no-MCP invariant check, and pushes the branch when there is
a resulting change. The transform regenerates Gemini manifests, the README
inventory, and generated docs as part of the rewrite. Add new MCP-backed
alternate-ref entries to `NO_MCP_REF_NAMES` in that script so the branch stays
reproducible.

Drift is checked by `.github/workflows/check-no-mcp-drift.yml` and
`plugins/scripts/check-no-mcp-drift --compare-ref`. The drift check builds an
expected tree from `origin/main` plus the no-MCP transform and compares it with
`origin/marketplace-no-mcp`; it also verifies that local plugin MCP configs and
Gemini `mcpServers` entries are absent from the no-MCP variant.

The no-MCP branch should allow GitHub Actions to push sync commits, but humans
should not casually push, merge, or close it. Treat direct human writes as
release-maintenance work: explain why the automation was not enough, run the
drift check afterward, and leave the branch as a long-lived variant.

Marketplace install smoke tests live in
`plugins/scripts/smoke-marketplace-install`. They add the marketplace to
isolated Claude and Codex homes, install the `acp` plugin, assert the Codex
catalog count matches the manifest, and install the matching Gemini extension.
CI runs that smoke against the current checkout and against both remote refs in
the scheduled no-MCP drift workflow.

Marketplace parity is enforced by `plugins/scripts/check-marketplace-sync` and
`.github/workflows/validate-marketplaces.yml`. The check fails on duplicate
plugin names, entries that exist in only one marketplace, or Claude/Codex source
targets that do not normalize to the same repo/path/ref. It also checks local
plugin packaging: any `plugins/*` directory with `.claude-plugin/plugin.json` or
`.codex-plugin/plugin.json` must have a sibling `gemini-extension.json`.

Schema and runtime validation lives in `plugins/scripts/validate-plugin-schemas`:
Claude marketplace/plugin JSON is checked against the published SchemaStore
schemas; Codex marketplace/plugin JSON is checked against local schemas derived
from the OpenAI Codex plugin docs and current parser behavior; Gemini extension
JSON is checked against a local schema derived from the Gemini CLI extension
reference and `ExtensionConfig`, then every local Gemini extension is checked
with `gemini extensions validate`. OpenAI and Gemini do not currently publish
standalone JSON Schema files for those plugin/extension manifests, so the local
schemas live under `plugins/schemas/` with provenance notes in each schema
description. Cross-runtime parity still comes from
`plugins/scripts/check-marketplace-sync`. Run `plugins/scripts/check-all` before
pushing, or enable the tracked hook with:

```bash
git config core.hooksPath .githooks
```

To review or refresh the schema provenance, run:

```bash
plugins/scripts/audit-upstream-schema-sources
```

Primary upstream references:

- Claude SchemaStore:
  `https://json.schemastore.org/claude-code-plugin-manifest.json` and
  `https://json.schemastore.org/claude-code-marketplace.json`
- Codex docs/spec:
  `https://developers.openai.com/codex/plugins/build` and
  `https://github.com/openai/codex/blob/main/codex-rs/skills/src/assets/samples/plugin-creator/references/plugin-json-spec.md`
- Codex parser sources:
  `https://github.com/openai/codex/blob/main/codex-rs/core-plugins/src/manifest.rs`
  and
  `https://github.com/openai/codex/blob/main/codex-rs/core-plugins/src/marketplace.rs`
- Gemini extension reference:
  `https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/reference.md`
- Gemini source/validator:
  `https://github.com/google-gemini/gemini-cli/blob/main/packages/cli/src/config/extension.ts`
  and
  `https://github.com/google-gemini/gemini-cli/blob/main/packages/cli/src/commands/extensions/validate.ts`

Operational docs live under `docs/`:

- `docs/installation.md`: install commands for Claude, Codex, Gemini, full
  marketplace, and no-MCP variant.
- `docs/marketplace-operations.md`: maintainer workflow for adding, updating,
  removing, and validating marketplace entries.
- `docs/plugin-documentation-standard.md`: README/CHANGELOG expectations and
  docs-quality enforcement.
- `docs/configuration.md`: plugin settings, generated env files, and secret
  handling.
- `docs/release-and-changelog.md`: root vs plugin changelog policy.

- `docs/plugin-matrix.md`: local plugin packaging across Claude, Codex, Gemini,
  skills, commands, README, and CHANGELOG coverage.
- `docs/configuration-matrix.md`: plugin config keys, env vars, sensitivity,
  descriptions, and consuming files.
- `docs/marketplace-sources.md`: Claude/Codex marketplace source, selector,
  and no-MCP ref inventory.
- `docs/schema-provenance.md`: local schema files and upstream references.
- `docs/no-mcp-variant.md`: the long-lived no-MCP branch behavior and
  ref-managed entries.

Regenerate them with `plugins/scripts/generate-docs`; `plugins/scripts/check-all`
uses `plugins/scripts/generate-docs --check` to fail on stale generated docs.
When generated docs are stale, the check prints the regeneration command and a
bounded diff preview.

## Inventory

<!-- BEGIN GENERATED README INVENTORY -->

<!-- Generated by plugins/scripts/generate-readme-inventory. Do not edit by hand. -->

- 25 local plugin directories
- 76 Claude marketplace entries
- 76 Codex/OpenAI marketplace entries
- 63 skills
- 63 OpenAI agent companion files
- 25 Gemini extension manifests
- 6 MCP config files, defining 5 MCP servers
- 3 command docs

| Plugin | Description | Skills | MCP servers | OpenAI agents | Commands |
|---|---|---|---|---:|---|
| `acp` | Rust implementation patterns for ACP, rmcp-derived MCP servers, and Lab runtime work. | rust | none | 1 | none |
| `adguard` | Skill for operating adguard via the lab MCP server / CLI. | adguard | none | 1 | none |
| `agent-os` | Drive the agent-os Windows 11 sandbox VM through the Labby gateway or an already-configured Windows-MCP endpoint. Ships the agent-os skill, a /agent-os status command, and a SessionStart health check. | agent-os | windows-mcp | 1 | agent-os.md |
| `arrs` | The *arr / media-automation stack in one plugin: Radarr, Sonarr, Prowlarr, Overseerr, SABnzbd, qBittorrent, Plex, Jellyfin, Tautulli, and Tracearr — each operated via its own REST API. Credentials are configured here and bridged to the skills via a generated env file. | jellyfin, overseerr, plex, prowlarr, qbittorrent, radarr, sabnzbd, sonarr, tautulli, tracearr | none | 10 | none |
| `broadcastr` | Helper assets for Broadcastr plugin tooling. | none | none | 0 | none |
| `bytestash` | Skills for operating a ByteStash snippet manager. | bytestash | none | 1 | none |
| `dozzle` | Skill for operating Dozzle through direct HTTP API checks, auth guidance, and MCP setup notes. | dozzle | dozzle | 1 | none |
| `immich` | Skill for operating immich via the lab MCP server / CLI. | immich | none | 1 | none |
| `linkding` | Skills for operating a Linkding bookmark manager. | linkding | none | 1 | none |
| `loggifly` | Skill for operating loggifly via the lab MCP server / CLI. | loggifly | none | 1 | none |
| `memos` | Skills for operating a Memos note hub. | memos | none | 1 | none |
| `navidrome` | Operate a self-hosted Navidrome music server through its Subsonic API with direct HTTP calls — ping, browse artists/albums, search, and list playlists. | navidrome | none | 1 | none |
| `neo4j` | Operate a Neo4j graph database with Cypher over the HTTP transactional API or cypher-shell. | neo4j | none | 1 | none |
| `notebooklm` | NotebookLM research, source, generation, and download workflows. | notebooklm | none | 1 | none |
| `plexus` | Remote-device memory and live operating context for host-specific work. | bootstrap-plexus, operating-remote | none | 2 | remote-context.md |
| `qdrant` | Vector database collections and semantic search via direct calls to the Qdrant REST API. | qdrant | none | 1 | none |
| `radicale` | CalDAV and CardDAV workflow skills for Radicale. | radicale | none | 1 | none |
| `scripts` | Shared Dendrite plugin maintenance scripts. | none | none | 0 | none |
| `scrutiny` | Inspect Scrutiny disk health and SMART status through Scrutiny's HTTP API. | scrutiny | none | 1 | none |
| `swag` | SWAG reverse proxy configuration management via MCP. Create, edit, view, and manage nginx proxy configurations with auth integration. | swag | swag-mcp, swag-mcp-remote | 1 | none |
| `tei` | Inspect and query a Text Embeddings Inference server through its HTTP API. | tei | none | 1 | none |
| `testing` | App-testing and MCP-tooling skills: live QA of web, Android, and desktop apps; MCP server smoke-testing (mcporter); MCP-UI / Apps validation (mcpjam); and claude-in-mobile device automation. | android-app-testing, claude-in-mobile, desktop-app-testing, mcpjam-ui-testing, mcporter, web-app-testing | none | 6 | none |
| `uptime-kuma` | Read-only monitoring of a self-hosted Uptime Kuma instance via direct HTTP — Prometheus /metrics (API-key auth) and public status-page JSON. No monitor management (that requires Uptime Kuma's socket.io API). | uptime-kuma | none | 1 | none |
| `vibin` | Workflow, repo, GitHub, Windows, Paperless, MCP gateway, Jetpack Compose, and SWAG utility skills. | check-skill-clis, chrome, claude-android-ninja, clipboard, create-swag-config, fastmcp-client-cli, gh-fix-ci, gh-pr, hand-off, homelab-map, jetpack-compose-expert, mcp-gateway-tools, monolith-check, nircmd, paperless-ngx, quick-push, rclone, refresh-docs, repo-status, save-to-md, screenshots, sysinternals, using-rmcp, validate-skill, work-it, worktree-setup | none | 26 | scaffold-claude-plugin.md |
| `zsnoop-mcp` | ZFS snapshot exploration and recovery over SSH through the zsnoop-mcp server. | zsnoop-mcp | zsnoop | 1 | none |

<!-- END GENERATED README INVENTORY -->

## Curated Marketplace Plugins

These marketplace entries are included by reference rather than carried as local
plugin source directories in this repo.

| Plugin | Source | Description |
|---|---|---|
| `lumen` | `github:jmagar/lumen` | Precise local semantic code search via MCP. Indexes your codebase with Go AST parsing and vector embeddings — Ollama, LM Studio, or HuggingFace TEI. |
| `agent-browser` | `github:vercel-labs/agent-browser` | Browser automation plugin for agent-driven web app testing, inspection, and debugging. |
| `axon` | `https://github.com/jmagar/axon.git`, `plugins/axon` | Skills and MCP configuration for the Axon crawl, ingest, embed, query, and RAG engine. |
| `cortex` | `https://github.com/jmagar/cortex.git`, `plugins/cortex` | Homelab syslog receiver plus MCP server for searching, tailing, and correlating logs across hosts. |
| `unraid` | `https://github.com/jmagar/unrust.git`, `plugins/unraid` | Unraid NAS/homelab monitoring via the unrust MCP server. |
| `rarcane` | `https://github.com/jmagar/rarcane.git`, `plugins/rarcane` | Arcane Docker management via the rarcane MCP server (Rust port of arcane-mcp). |
| `rtemplate` | `https://github.com/jmagar/rtemplate-mcp.git`, `plugins/rtemplate` | Reference rmcp template/example MCP server — scaffold for building new Rust MCP servers. |
| `tailscale` | `https://github.com/jmagar/rustscale.git`, `plugins/tailscale` | Tailscale network management via the rustscale MCP server — query devices, ACL, DNS, users, and API keys. |
| `gotify` | `https://github.com/jmagar/rustify.git`, `plugins/gotify` | Gotify push notification server via the rustify MCP server. |
| `unifi` | `https://github.com/jmagar/rustifi.git`, `plugins/unifi` | UniFi network management via the rustifi MCP server — monitor devices, clients, health, alarms, events, and WLANs. |
| `unifi-network` | `https://github.com/sirkirby/unifi-mcp.git`, `plugins/unifi-network` | UniFi Network MCP server (sirkirby/unifi-mcp) — manage network devices, clients, firewall, VPN, and more. |
| `apprise` | `https://github.com/jmagar/apprise-mcp.git`, `plugins/apprise` | Send push notifications via apprise-mcp — a Rust MCP bridge to the Apprise universal notification library. |
| `codex-plugin-cc` | `github:openai/codex-plugin-cc` | OpenAI Codex plugin for Claude Code interoperability. |
| `agent-sdk-dev` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/agent-sdk-dev` | Development kit for working with the Claude Agent SDK |
| `beads` | `https://github.com/gastownhall/beads.git`, `plugins/beads` | AI-supervised issue tracker for coding workflows |
| `chrome-devtools-mcp` | `https://github.com/ChromeDevTools/chrome-devtools-mcp.git` | Control and inspect a live Chrome browser from your coding agent. Record performance traces, analyze network requests, check console messages with source-mapped stack traces, and automate browser actions with Puppeteer. |
| `claude-code-setup` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/claude-code-setup` | Analyze codebases and recommend tailored Claude Code automations such as hooks, skills, MCP servers, and subagents. |
| `claude-md-management` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/claude-md-management` | Tools to maintain and improve CLAUDE.md files - audit quality, capture session learnings, and keep project memory current. |
| `code-review` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/code-review` | Automated code review for pull requests using multiple specialized agents with confidence-based scoring to filter false positives |
| `code-simplifier` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/code-simplifier` | Agent that simplifies and refines code for clarity, consistency, and maintainability while preserving functionality. Focuses on recently modified code. |
| `comprehensive-review` | `https://github.com/wshobson/agents.git`, `plugins/comprehensive-review` | Multi-perspective code analysis covering architecture, security, and best practices |
| `discord` | `https://github.com/anthropics/claude-plugins-official.git`, `external_plugins/discord` | Discord messaging bridge with built-in access control. Manage pairing, allowlists, and policy via /discord:access. |
| `fakechat` | `https://github.com/anthropics/claude-plugins-official.git`, `external_plugins/fakechat` | Localhost web chat for testing the channel notification flow. No tokens, no access control, no third-party service. |
| `feature-dev` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/feature-dev` | Comprehensive feature development workflow with specialized agents for codebase exploration, architecture design, and quality review |
| `frontend-design` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/frontend-design` | Create distinctive, production-grade frontend interfaces with high design quality. Generates creative, polished code that avoids generic AI aesthetics. |
| `gopls-lsp` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/gopls-lsp` | Go language server for code intelligence and refactoring |
| `kotlin-lsp` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/kotlin-lsp` | Kotlin language server for code intelligence |
| `lavra` | `https://github.com/roberto-mello/lavra.git`, `plugins/lavra` | 30 specialized agents, 28 commands, 15 skills, persistent memory with auto-recall |
| `mcp-server-dev` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/mcp-server-dev` | Skills for designing and building MCP servers that work seamlessly with Claude. Guides you through deployment models (remote HTTP, MCPB, local), tool design patterns, auth, and interactive MCP apps. |
| `playground` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/playground` | Creates interactive HTML playgrounds — self-contained single-file explorers with visual controls, live preview, and prompt output with copy button. Includes templates for design playgrounds, data explorers, concept maps, and document critique. |
| `plugin-dev` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/plugin-dev` | Comprehensive toolkit for developing Claude Code plugins. Includes 7 expert skills covering hooks, MCP integration, commands, agents, and best practices. AI-assisted plugin creation and validation. |
| `pr-review-toolkit` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/pr-review-toolkit` | Comprehensive PR review agents specializing in comments, tests, error handling, type design, code quality, and code simplification |
| `pyright-lsp` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/pyright-lsp` | Python language server (Pyright) for type checking and code intelligence |
| `ralph-loop` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/ralph-loop` | Interactive self-referential AI loops for iterative development, implementing the Ralph Wiggum technique. Claude works on the same task repeatedly, seeing its previous work, until completion. |
| `rust-analyzer-lsp` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/rust-analyzer-lsp` | Rust language server for code intelligence and analysis |
| `serena` | `https://github.com/anthropics/claude-plugins-official.git`, `external_plugins/serena` | Semantic code analysis MCP server providing intelligent code understanding, refactoring suggestions, and codebase navigation through language server protocol integration. |
| `session-report` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/session-report` | Generate an explorable HTML report of Claude Code session usage — tokens, cache efficiency, subagents, skills, and the most expensive prompts — from local ~/.claude/projects transcripts. |
| `skill-creator` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/skill-creator` | Create new skills, improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, update or optimize an existing skill, run evals to test a skill, or benchmark skill performance with variance analysis. |
| `superpowers` | `https://github.com/obra/superpowers.git` | Core skills library: TDD, debugging, collaboration patterns, and proven techniques |
| `telegram` | `https://github.com/anthropics/claude-plugins-official.git`, `external_plugins/telegram` | Telegram messaging bridge with built-in access control. Manage pairing, allowlists, and policy via /telegram:access. |
| `typescript-lsp` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/typescript-lsp` | TypeScript/JavaScript language server for enhanced code intelligence |
| `webwright` | `https://github.com/microsoft/Webwright.git` | Turn your coding agent into a browser agent using a local Playwright workspace, screenshots, action logs, and visual self-verification. |
| `zsh-tool` | `github:ArkTechNWA/zsh-tool` | Zsh shell for Claude Code - full terminal control, live output, PTY mode for interactive commands |
| `mcp-apps` | `https://github.com/modelcontextprotocol/ext-apps.git`, `plugins/mcp-apps` | Claude Code skill for building MCP Apps with interactive UIs |
| `nvidia-skills` | `https://github.com/NVIDIA/skills.git`, `plugins/nvidia-skills` | NVIDIA agent skills for accelerated-computing workflows — starting with cuOpt vehicle-routing optimization (VRP, TSP, PDP) via the cuOpt Python API. |
| `qdrant-skills` | `https://github.com/qdrant/skills.git` | Agent skills for Qdrant vector search covering scaling, performance optimization, search quality, monitoring, deployment, model migration, version upgrades, and SDK usage. |
| `redis-development` | `https://github.com/redis/agent-skills.git`, `plugins/redis-development` | Redis development best practices — data structures, query engine, vector search, caching, and performance optimization |
| `mcp-tunnels` | `https://github.com/anthropics/claude-plugins-official.git`, `plugins/mcp-tunnels` | Connect Claude to a private MCP server through an Anthropic-managed tunnel. |
| `ytdl-mcp` | `github:jmagar/ytdl-mcp` | Download audio/video from any yt-dlp-supported site, embed metadata and cover art, organize by artist, and rsync to an SSH remote with separate audio/video destinations. |
| `labby` | `https://github.com/jmagar/lab.git`, `plugins/labby` | Skills and MCP configuration for the Lab homelab control plane. |

## Layout Rules

- Keep portable marketplace plugins in `plugins/<name>/`.
- Keep Lab's own control-plane plugin in `jmagar/lab/plugins/labby` and reference
  it from the marketplace as a GitHub subdirectory source.
- Every skill at `plugins/*/skills/*/SKILL.md` must have
  `agents/openai.yaml` next to it.
- Every plugin directory at `plugins/*` must have a `gemini-extension.json`
  manifest. Run `plugins/scripts/generate-gemini-extensions` after changing
  plugin metadata, user config, or MCP server snippets.
- Prefer updating marketplace manifests and plugin manifests together so Claude
  Code and Codex stay aligned.
