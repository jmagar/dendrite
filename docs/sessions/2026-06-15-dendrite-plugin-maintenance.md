---
date: 2026-06-15 18:25:17 EDT
repo: git@github.com:jmagar/dendrite.git
branch: codex/dendrite-gemini-skill-marketplace
head: 9c3f043
working directory: /home/jmagar/workspace/dendrite
worktree: /home/jmagar/workspace/dendrite 9c3f043 [codex/dendrite-gemini-skill-marketplace]
---

# Dendrite plugin maintenance

## User Request

Review and clean up Dendrite's plugin and skill catalog, remove duplicated
skills when dedicated plugins exist, add missing documentation, add useful skill
scripts, create Gemini extension manifests, then stage, commit, and push the
work.

## Session Overview

This session updated the Dendrite marketplace and local plugin catalog across
Claude Code, Codex, and Gemini CLI surfaces. The batch removed duplicate Vibin
skills, removed the Bitwarden plugin, moved snippet creation to Labby, added
missing skill README and changelog files, expanded the Rust skill, added helper
scripts for selected service skills, and generated Gemini extension manifests
for every local plugin directory.

## Sequence of Events

1. Reviewed skill/plugin inventory and duplicate coverage.
2. Removed Bitwarden and redundant Vibin skills where standalone plugins or
   dedicated repos now own the capability.
3. Added missing README and CHANGELOG files for skills and created the root
   changelog.
4. Reworked the Rust skill using patterns observed in related Rust projects.
5. Added helper scripts for high-friction service/API skills.
6. Checked `../ytdl-mcp`, confirmed it has its own `ytdl` skill, and removed
   Vibin's duplicate `yt-dlp` skill.
7. Added Gemini CLI `gemini-extension.json` manifests for all local plugins and
   a generator script to keep them current.

## Key Findings

- Dendrite should not carry `plugins/labby`; Labby remains sourced from the Lab
  repository and referenced by marketplace metadata.
- The dedicated `../ytdl-mcp/skills/ytdl/SKILL.md` covers yt-dlp workflows, so
  Vibin's `yt-dlp` skill was duplicate coverage.
- Gemini CLI uses per-extension manifests rather than a Dendrite-style
  marketplace manifest, so every local plugin directory now has a
  `gemini-extension.json`.
- Several HTTP-heavy service skills had repeated curl/auth setup that justified
  script wrappers.

## Technical Decisions

- Generated Gemini manifests from existing Claude/Codex plugin metadata to avoid
  hand-maintained drift.
- Kept Gemini manifests conservative: stable fields only, env-var settings for
  user configuration, and MCP server snippets only where existing plugin config
  could be converted cleanly.
- Added service scripts only where they remove repeated auth, URL, or command
  boilerplate.
- Left ignored Rust `target/` metadata under `plugins/broadcastr` untracked
  because repo ignore rules exclude `**/target/`.

## Files Changed

| status | path | previous path | purpose | evidence |
|---|---|---|---|---|
| created | CHANGELOG.md | - | Add global repo changelog | `test -f CHANGELOG.md` |
| modified | README.md | - | Update inventory, curated plugins, Gemini manifest rules, and counts | `rg "Gemini extension" README.md` |
| modified | .claude-plugin/marketplace.json | - | Remove Bitwarden and align marketplace entries | `jq empty .claude-plugin/marketplace.json` |
| modified | .agents/plugins/marketplace.json | - | Remove Bitwarden and align marketplace entries | `jq empty .agents/plugins/marketplace.json` |
| deleted | plugins/bitwarden/** | - | Remove Bitwarden plugin | `git status --short` |
| deleted | plugins/vibin/skills/agent-os/** | - | Remove duplicate Vibin skill | `test ! -e plugins/vibin/skills/agent-os` |
| deleted | plugins/vibin/skills/create-swag-config/** | - | Remove duplicate Vibin skill | `test ! -e plugins/vibin/skills/create-swag-config` |
| deleted | plugins/vibin/skills/creating-snippets/** | /home/jmagar/workspace/lab/plugins/labby/skills/creating-snippets | Move snippet skill to Labby | `test ! -e plugins/vibin/skills/creating-snippets` |
| deleted | plugins/vibin/skills/desktop-app-testing/** | - | Remove duplicate Vibin skill | `test ! -e plugins/vibin/skills/desktop-app-testing` |
| deleted | plugins/vibin/skills/mcpjam-inspector/** | - | Remove duplicate Vibin skill | `test ! -e plugins/vibin/skills/mcpjam-inspector` |
| deleted | plugins/vibin/skills/yt-dlp/** | - | Remove duplicate now owned by ytdl-mcp | `test ! -e plugins/vibin/skills/yt-dlp` |
| modified | plugins/acp/skills/rust/** | - | Expand Rust skill patterns | `git status --short plugins/acp/skills/rust` |
| created | plugins/*/gemini-extension.json | - | Add Gemini CLI extension manifests | `find plugins -name gemini-extension.json` |
| created | plugins/scripts/generate-gemini-extensions | - | Regenerate Gemini manifests deterministically | `plugins/scripts/generate-gemini-extensions` |
| created | plugins/*/skills/*/README.md and CHANGELOG.md | - | Fill missing skill docs | skill docs completeness check |
| created | selected `scripts/` helpers | - | Add repeatable API/test helpers | `bash -n` and `--help` checks |
| modified | many existing skill docs, references, scripts, and OpenAI companions | - | Reviewer-driven fixes and metadata cleanup | `git diff --stat HEAD` |

## Beads Activity

No bead activity observed. `bd list --all --sort updated --reverse --limit 20
--json` returned `[]`.

## Repository Maintenance

- Plans: no `docs/plans` files were present.
- Beads: checked; no bead records were present.
- Worktrees and branches: current worktree is
  `/home/jmagar/workspace/dendrite` on
  `codex/dendrite-gemini-skill-marketplace`; no stale worktree cleanup was
  attempted.
- Stale docs: root README and global changelog were updated to reflect current
  inventory and Gemini support.
- Ignored artifacts: Rust `target/` files under `plugins/broadcastr` are ignored
  by `**/target/` and were not staged.

## Tools and Skills Used

- Shell commands: repository inventory, git status, jq validation, find/rg
  checks, script syntax checks, Gemini CLI validation.
- File editing tools: `apply_patch` for repository edits.
- Web/docs lookup: official Gemini CLI extension reference and writing guide.
- Skills: `quick-push`, `save-to-md`, `plugin-creator`,
  `superpowers:writing-skills`, and `verification-before-completion`.
- MCP tools: Lumen semantic search was attempted and fell back to direct shell
  inspection after an embedding overload.

## Commands Executed

| command | result |
|---|---|
| `git switch -c codex/dendrite-gemini-skill-marketplace` | created feature branch |
| `jq empty .claude-plugin/marketplace.json && jq empty .agents/plugins/marketplace.json` | passed |
| `bash -n <new scripts>` | passed |
| `<new script> --help` | passed for all new helpers |
| `plugins/scripts/generate-gemini-extensions` | generated 24 manifests |
| `gemini extensions validate <plugin>` | exited 0 for all plugin dirs; emitted unrelated user policy warnings |
| `git diff --check` | passed |

## Errors Encountered

- Lumen semantic search returned an embedding overload. Direct repository
  inspection was used instead.
- `gemini extensions validate` printed unrelated global policy warnings from
  `auto-saved.toml`, but the extension validation commands exited 0.
- Initial inventory counts drifted after duplicate skill removals; README counts
  were corrected to 60 skills and 60 OpenAI companions.

## Behavior Changes (Before/After)

| area | before | after |
|---|---|---|
| Dendrite skills | Duplicate skills remained in Vibin | Duplicates removed where dedicated plugins own the capability |
| Skill docs | Some skills lacked README/CHANGELOG files | Current skills have README, CHANGELOG, SKILL, and OpenAI companion files |
| Service helpers | Several skills repeated auth/curl setup in prose | High-friction skills have executable helpers |
| Gemini support | Local plugins had no Gemini manifests | Every local plugin has `gemini-extension.json` |
| Rust skill | ACP-focused guidance only | Broader Rust patterns for rmcp-family, Lab, Cortex, Rustarr, and Axon work |

## Verification Evidence

| command | expected | actual | status |
|---|---|---|---|
| `jq empty .claude-plugin/marketplace.json && jq empty .agents/plugins/marketplace.json` | Marketplace JSON parses | exit 0 | pass |
| skill docs completeness loop | no missing files | exit 0 | pass |
| `bash -n` on new scripts | shell syntax valid | exit 0 | pass |
| new scripts `--help` loop | help runs without secrets | exit 0 | pass |
| custom Gemini manifest validator | valid shape | `validated gemini manifests` | pass |
| `gemini extensions validate <plugin>` | Gemini accepts each extension | exit 0 for all plugin dirs, unrelated policy warnings printed | pass |
| `git diff --check` | no whitespace errors | exit 0 | pass |
| duplicate absence tests | duplicate paths absent | exit 0 | pass |

## Risks and Rollback

- Risk: large catalog changes touch many skill files and marketplace metadata.
  Rollback is the pushed commit revert.
- Risk: Gemini support is manifest-level only; gallery distribution may still
  require per-extension repo or archive packaging.
- Risk: service helper scripts depend on local env/config conventions.

## Decisions Not Taken

- Did not add `plugins/labby`; Labby remains externally sourced from the Lab
  repo.
- Did not commit ignored Rust `target/` files under `plugins/broadcastr`.
- Did not create a traditional Gemini marketplace file because Gemini CLI uses
  per-extension manifests.

## References

- Official Gemini CLI extension reference:
  https://raw.githubusercontent.com/google-gemini/gemini-cli/main/docs/extensions/reference.md
- Official Gemini CLI writing extensions guide:
  https://raw.githubusercontent.com/google-gemini/gemini-cli/main/docs/extensions/writing-extensions.md

## Next Steps

- Commit and push this session log as a path-limited documentation commit.
- Stage, commit, and push the full Dendrite plugin maintenance batch.
- After push, install or link one or two Gemini extensions locally for runtime
  smoke testing if desired.
