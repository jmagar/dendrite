# Changelog

## Unreleased

- Skill quality pass: sharpened `claude-in-mobile`'s scope versus `android-app-testing`, guarded the version-varying `mcpjam-ui-testing` render flags, and moved `mcporter` harness lore into `references/`.

## 0.1.0

- Initial release. Consolidates the app-testing and MCP-tooling skills into one plugin: web-app-testing, android-app-testing, desktop-app-testing, mcpjam-ui-testing, mcporter, claude-in-mobile (moved from the `vibin` plugin).
- No plugin-level configuration; each skill carries its own scripts and references.
