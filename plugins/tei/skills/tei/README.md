# TEI

Use when calling Hugging Face Text Embeddings Inference for health, model info, embeddings, sparse embeddings, reranking, or tokenization.

## Usage

Invoke this skill when the user request matches the trigger conditions in `SKILL.md`. The skill body is the source of truth for workflow steps, safety rules, and operational constraints.

## Configuration

Configure `tei_url` and optional sensitive `tei_auth_header` in Claude plugin
settings or Gemini extension settings. The plugin hook writes
`${XDG_CONFIG_HOME:-~/.config}/lab-tei/config.env`; legacy `~/.lab/.env`
remains a local fallback during migration.

## Files

- `SKILL.md` - agent workflow and trigger guidance
- `scripts/tei-api.sh` - repeatable TEI HTTP helper
- `agents/` - OpenAI runtime metadata
- `README.md` - packaging overview
- `CHANGELOG.md` - packaging change history
