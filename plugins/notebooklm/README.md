# NotebookLM

Automate Google NotebookLM workflows through `notebooklm-py`: create notebooks,
add sources, chat with content, generate artifacts, wait for long-running jobs,
and download generated content.

## Configuration

NotebookLM authentication is managed by the `notebooklm` CLI, not a Dendrite
setup hook. Run `notebooklm login` once for an interactive profile, or use
`NOTEBOOKLM_HOME`, `NOTEBOOKLM_PROFILE`, and `NOTEBOOKLM_AUTH_JSON` for isolated
automation or parallel agents.

## Skill

- `skills/notebooklm/SKILL.md` — full command policy, authentication guidance,
  parallel-agent cautions, and artifact workflow reference.

## Verify

```bash
notebooklm status
notebooklm list --json
```
