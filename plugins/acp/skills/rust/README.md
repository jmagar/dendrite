# Rust Patterns

Use when working on Rust code in the rmcp server family, including service layering, MCP/CLI parity, action dispatch, schemas, auth, testing, build setup, and ACP runtime integration.

## Usage

Invoke this skill when the user request matches the trigger conditions in `SKILL.md`. The skill body is the source of truth for workflow steps, safety rules, and operational constraints.

## Files

- `SKILL.md` - agent workflow and trigger guidance
- `agents/` - OpenAI runtime metadata
- `references/` - progressively loaded reference material
- `examples/` - example workflows and usage notes
- `README.md` - packaging overview
- `CHANGELOG.md` - packaging change history
