# Dendrite

Dendrite is the Claude Code and Codex marketplace home for agent plugins, skills,
MCP integrations, hooks, commands, and OpenAI agent companion files.

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

## Inventory

- 24 local plugin directories
- 72 marketplace entries
- 60 skills
- 60 OpenAI agent companion files
- 24 Gemini extension manifests
- 5 MCP config files, defining 5 MCP servers
- 3 command docs

| Plugin | Description | Skills | MCP servers | OpenAI agents | Commands |
|---|---|---|---|---:|---|
| `acp` | Rust patterns for Jacob's rmcp-family servers, Lab runtime work, and ACP integrations. | rust | none | 1 | none |
| `adguard` | Skill for operating adguard via the lab MCP server / CLI. | adguard | none | 1 | none |
| `agent-os` | Drive the agent-os Windows 11 sandbox VM through its Windows-MCP server. Self-registers the windows-mcp MCP from your configured URL + bearer token, ships the agent-os skill, a /agent-os status command, and a SessionStart health check. | agent-os | windows-mcp | 1 | agent-os.md |
| `arrs` | The *arr / media-automation stack in one plugin: Radarr, Sonarr, Prowlarr, Overseerr, SABnzBD, qBittorrent, Plex, Jellyfin, Tautulli, and Tracearr, each operated via its own REST API. Credentials are configured here and bridged to the skills via a generated env file. | jellyfin, overseerr, tautulli, sabnzbd, radarr, tracearr, prowlarr, plex, qbittorrent, sonarr | none | 10 | none |
| `broadcastr` | Helper assets for Broadcastr plugin tooling. | none | none | 0 | none |
| `bytestash` | Skills for operating a ByteStash snippet manager. | bytestash | none | 1 | none |
| `dozzle` | Skill for operating Dozzle through direct HTTP API checks, auth guidance, and MCP setup notes. | dozzle | dozzle | 1 | none |
| `immich` | Skill for operating immich via the lab MCP server / CLI. | immich | none | 1 | none |
| `linkding` | Skills for operating a Linkding bookmark manager. | linkding | none | 1 | none |
| `loggifly` | Skill for operating loggifly via the lab MCP server / CLI. | loggifly | none | 1 | none |
| `memos` | Skills for operating a Memos note hub. | memos | none | 1 | none |
| `navidrome` | Operate a self-hosted Navidrome music server through its Subsonic API with direct HTTP calls: ping, browse artists/albums, search, and list playlists. | navidrome | none | 1 | none |
| `neo4j` | Skill for operating neo4j via the lab MCP server / CLI. | neo4j | none | 1 | none |
| `notebooklm` | NotebookLM research, source, generation, and download workflows. | notebooklm | none | 1 | none |
| `plexus` | Remote-device memory and live operating context for host-specific work. | bootstrap-plexus, operating-remote | none | 2 | remote-context.md |
| `qdrant` | Skill for operating qdrant via the lab MCP server / CLI. | qdrant | none | 1 | none |
| `radicale` | CalDAV and CardDAV workflow skills for Radicale. | radicale | none | 1 | none |
| `scripts` | Shared plugin maintenance scripts. | none | none | 0 | none |
| `scrutiny` | Skill for operating scrutiny via the lab MCP server / CLI. | scrutiny | none | 1 | none |
| `swag` | SWAG reverse proxy configuration management via MCP. Create, edit, view, and manage nginx proxy configurations with auth integration. | swag | swag-mcp, swag-mcp-remote | 1 | none |
| `tei` | Skill for operating tei via the lab MCP server / CLI. | tei | none | 1 | none |
| `testing` | App-testing and MCP-tooling skills: live QA of web, Android, and desktop apps; MCP server smoke-testing with mcporter; MCP-UI / Apps validation with mcpjam; and claude-in-mobile device automation. | mcpjam-ui-testing, android-app-testing, desktop-app-testing, web-app-testing, mcporter, claude-in-mobile | none | 6 | none |
| `uptime-kuma` | Read-only monitoring of a self-hosted Uptime Kuma instance via direct HTTP: Prometheus `/metrics` with API-key auth and public status-page JSON. No monitor management. | uptime-kuma | none | 1 | none |
| `vibin` | Session, GitHub review, CI, repo status, and agent workflow skills for quick push, session documentation, PR comments, CI debugging, and branch/worktree readiness audits. | refresh-docs, summarize, gh-fix-ci, rclone, check-skill-clis, save-to-md, jetpack-compose-expert, work-it, sysinternals, paperless-ngx, claude-android-ninja, clipboard, hand-off, quick-push, nircmd, validate-skill, gh-pr, using-rmcp, chrome, repo-status, screenshots, aurora-design-system, homelab-map, mcp-gateway-tools, fastmcp-client-cli | none | 25 | scaffold-claude-plugin.md |

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
