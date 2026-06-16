# Changelog

All notable changes to this skill are recorded here. Format roughly follows [Keep a Changelog](https://keepachangelog.com/).

## 2026-06-16

### Changed

- Restored the skill to Vibin after removing the retired standalone `swag-mcp` marketplace entry.
- Replaced hardcoded homelab hostnames, domains, paths, and IPs with `SWAG_*` deployment variables.
- Changed the workflow to direct SSH/file operations instead of the retired `swag-mcp` MCP server.
- Added strict `.subdomain.conf` filename validation and a transactional write flow that restores the prior config if `nginx -t` fails.
- Clarified that QUIC/HTTP3 should only be rendered when the target SWAG host already has a confirmed local include or listen pattern.

## 2026-05-17

### Added

- Initial release of the `create-swag-config` skill.
- `SKILL.md` covering the original MCP-assisted path and fallback hand-write path. These entries are historical; the current skill uses direct SSH/file writes.
- `references/examples.md` — originally annotated deployed configs with the differences highlighted.
- `references/fallback-template.md` — originally documented a full nginx server-block template plus save/reload procedure.
- `references/includes.md` — originally documented deployed SWAG include files and when to use them.
- `README.md` — human-facing overview, when-to-invoke, file layout, related skills.

### Skill-review polish applied before first ship

The skill was reviewed by `plugin-dev:skill-reviewer` after initial draft. Changes from that review:

- **Corrected the legacy MCP tool surface.** First draft listed separate CRUD tools; the retired server exposed one action-dispatched tool.
- **Named the gateway-side server alias** in the original deployment notes.
- **Added a concrete `action: "create"` JSON example** for the then-current MCP-assisted workflow.
- **Moved the 50-line hand-write template** out of `SKILL.md` and into `references/fallback-template.md`.
- **Moved the "what each include does" table** out of `SKILL.md` and into `references/includes.md`.
- **Added a DNS + cert note** for wildcard-domain deployments.
- **Added a filewatch latency note**: SWAG picks up new configs in ~30 seconds; don't panic-restart.
- **Documented the `view` action** as the read tool (the previously-unnamed "diff before edit" path).
- **Documented the `samples` filter** on `list` (returns LinuxServer-shipped `*.subdomain.conf.sample` reference configs to crib from for non-MCP services).
- **Updated verification checklist** to use the then-current `swag` health and logs actions.

### Skill metadata

- `name: create-swag-config`
- description length: ~960 chars (under the 1024 cap)
- passes `skills-ref validate`
- symlinked into `~/.claude/skills/create-swag-config`

## 2026-05-17 (post-ship correction)

### Changed

- **Re-anchored `references/fallback-template.md` on `_template.subdomain.conf.sample`** from the target SWAG host. The first draft documented an MCP-specific shape (server-level `set $upstream_*`, multiple location blocks, `mcp-*` includes) as if it were the baseline. The LSIO sample is the baseline; MCP services are a deviation that layers extra structure on top.
- Hand-write decision tree clarified: plain web → start from `_template.subdomain.conf.sample`; MCP-aware → start from a deployed config (`lab` / `syslog` / `axon`).
