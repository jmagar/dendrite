# Dendrite

Dendrite is the Claude Code and Codex marketplace home for agent plugins, skills,
MCP integrations, hooks, commands, and OpenAI agent companion files.

It is split out from `jmagar/lab` so the Lab control plane can stay focused on
the `labby` runtime while the agent capability catalog can evolve as its own
public repo.

## Marketplace Files

- `.claude-plugin/marketplace.json`: Claude Code marketplace manifest.
- `.agents/plugins/marketplace.json`: Codex/OpenAI agent marketplace manifest.
- `plugins/`: local plugin sources carried by this repo.

`plugins/labby` intentionally stays in `jmagar/lab`. The marketplace still
publishes `labby` as an external GitHub subdirectory source:
`https://github.com/jmagar/lab.git`, path `plugins/labby`.

## Inventory

- 25 local plugin directories
- 73 marketplace entries
- 68 skills
- 68 OpenAI agent companion files
- 6 MCP config files, defining 5 MCP servers
- 6 command docs

| Plugin | Description | Skills | MCP servers | OpenAI agents | Commands |
|---|---|---|---|---:|---|
| `acp` | Agent Client Protocol skills for Rust, Python, and TypeScript implementations. | rust | none | 1 | none |
| `adguard` | Skill for operating adguard via the lab MCP server / CLI. | adguard | none | 1 | none |
| `agent-os` | Drive the agent-os Windows 11 sandbox VM through its Windows-MCP server. Self-registers the windows-mcp MCP from your configured URL + bearer token, ships the agent-os skill, a /agent-os status command, and a SessionStart health check. | agent-os | windows-mcp | 1 | agent-os.md |
| `arrs` | The *arr / media-automation stack in one plugin: Radarr, Sonarr, Prowlarr, Overseerr, SABnzBD, qBittorrent, Plex, Jellyfin, Tautulli, and Tracearr, each operated via its own REST API. Credentials are configured here and bridged to the skills via a generated env file. | jellyfin, overseerr, tautulli, sabnzbd, radarr, tracearr, prowlarr, plex, qbittorrent, sonarr | none | 10 | none |
| `bitwarden` | Bitwarden and secrets-management workflows for homelab operations. | bitwarden | bitwarden | 1 | bw-list.md, bw-get.md, bw-generate.md |
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
| `vibin` | Session, GitHub review, CI, repo status, and agent workflow skills for quick push, session documentation, PR comments, CI debugging, and branch/worktree readiness audits. | refresh-docs, create-swag-config, summarize, gh-fix-ci, rclone, check-skill-clis, save-to-md, jetpack-compose-expert, work-it, sysinternals, mcpjam-inspector, paperless-ngx, claude-android-ninja, agent-os, clipboard, hand-off, yt-dlp, quick-push, nircmd, creating-snippets, validate-skill, gh-pr, using-rmcp, chrome, desktop-app-testing, repo-status, screenshots, aurora-design-system, homelab-map, mcp-gateway-tools, fastmcp-client-cli | none | 31 | scaffold-claude-plugin.md |

## Layout Rules

- Keep portable marketplace plugins in `plugins/<name>/`.
- Keep Lab's own control-plane plugin in `jmagar/lab/plugins/labby` and reference
  it from the marketplace as a GitHub subdirectory source.
- Every skill at `plugins/*/skills/*/SKILL.md` must have
  `agents/openai.yaml` next to it.
- Prefer updating marketplace manifests and plugin manifests together so Claude
  Code and Codex stay aligned.

