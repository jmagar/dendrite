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

## Common Checks

```bash
# No local labby plugin copy.
test ! -e plugins/labby

# Every skill has an OpenAI companion file.
for f in $(find plugins -path '*/skills/*/SKILL.md' -type f | sort); do
  dir=${f%/SKILL.md}
  test -f "$dir/agents/openai.yaml" || echo "missing companion: $dir"
done

# Marketplace manifests parse.
jq empty .claude-plugin/marketplace.json
jq empty .agents/plugins/marketplace.json
```

