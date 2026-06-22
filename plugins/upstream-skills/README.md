# upstream-skills

Agent skills vendored verbatim from upstream repositories and kept in sync with
their sources via `plugins/scripts/sync-upstream-skills`.

Each `skills/<name>/` directory mirrors a whole upstream skill folder (SKILL.md
plus any references/scripts). The only dendrite-local file per skill is
`agents/openai.yaml`, which the sync tool preserves across updates.

## Sources

Provenance for every skill — repo, ref, path, pinned commit, and content hash —
lives in [`upstream-sources.json`](upstream-sources.json).

## Syncing

- `plugins/scripts/sync-upstream-skills check` — report drift from upstream.
- `plugins/scripts/sync-upstream-skills apply --all` — pull upstream updates.
- `plugins/scripts/sync-upstream-skills add <github-folder-url>` — vendor a new
  skill from a single URL.
