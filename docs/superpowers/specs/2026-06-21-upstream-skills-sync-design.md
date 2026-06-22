# Upstream Skills Vendoring + Sync — Design

Date: 2026-06-21
Status: Approved (pending spec review)

## Problem

We want to vendor seven skills that live in external upstream repos into
dendrite's marketplace, and have a repeatable way to keep the vendored copies in
sync with their upstream sources. Vendoring must capture the **entire skill
folder** (SKILL.md plus any `references/`, `scripts/`, and other files), never
just `SKILL.md`. Sync must detect when *any* file in an upstream skill folder
changes (including references/scripts, additions, and deletions).

## Sources

Seven skills across four upstream repos (all under the `openclaw` org):

| Skill | Repo | Path in repo | Upstream contents |
|---|---|---|---|
| `gog` | `openclaw/gogcli` | `.agents/skills/gog` | SKILL.md only |
| `acpx` | `openclaw/acpx` | `skills/acpx` | SKILL.md only |
| `meme-maker` | `openclaw/openclaw` | `skills/meme-maker` | SKILL.md + references + scripts |
| `agent-transcript` | `openclaw/agent-skills` | `skills/agent-transcript` | full folder |
| `autoreview` | `openclaw/agent-skills` | `skills/autoreview` | full folder |
| `handoff` | `openclaw/agent-skills` | `skills/handoff` | full folder |
| `session-viewer` | `openclaw/agent-skills` | `skills/session-viewer` | full folder |

Upstream paths differ per repo (`.agents/skills/` vs `skills/`), and one repo
(`agent-skills`) supplies four skills. The sync manifest must therefore map each
skill independently: `repo + branch + src_path -> dest`.

## Decisions (from brainstorming)

1. **Packaging:** one new plugin, `plugins/upstream-skills/`, holding all seven
   skills.
2. **Sync behavior:** a single tool with two modes — `--check` (report drift,
   non-zero exit on drift) and `--apply` (pull upstream content into the vendored
   folders). The tool never commits; the human reviews `git diff` and commits.
3. **Provenance:** the manifest records the pinned upstream commit SHA per skill
   for reproducible applies and reporting.
4. **Drift signal:** ground truth is a **content hash over the entire skill
   subtree** (every upstream-owned file), so changes to references/scripts,
   added files, and deleted files are all caught — not just SKILL.md edits.
5. **CI:** out of scope for now. The deliverable is the script + manifest. A
   scheduled `--check` workflow can be added later, mirroring
   `check-no-mcp-drift.yml`.
6. **Minimal configuration:** adding a skill must require nothing more than
   pasting the GitHub URL of the skill folder. The tool derives every manifest
   field from the URL, resolves the SHA, vendors the folder, and auto-generates
   the `agents/openai.yaml` stub. No hand-editing the manifest to onboard a
   skill.

## Minimal-config principle

A GitHub folder or file URL already encodes repo, ref, and path:

```
https://github.com/openclaw/openclaw/tree/main/skills/meme-maker
        └─owner─┘ └─repo─┘     └ref┘└────── src_path ──────┘

https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md
        └─owner─┘ └─repo─┘      └ref┘└──────── path ────────┘
```

The tool parses both forms:
- `/tree/<ref>/<path…>` → `src_path` = `<path…>` (folder).
- `/blob/<ref>/<path…>/SKILL.md` → `src_path` = `<path…>` (strip the trailing
  `/SKILL.md`).

From `src_path` it derives `name` = last path segment, and `branch` = `<ref>`.
`ref` is taken as the first segment after `blob`/`tree`; branches containing
slashes are the one case that needs a manual manifest edit (documented; not
expected for these sources). The user pastes a URL; the tool does the rest.

## Layout

```
plugins/upstream-skills/
├── .claude-plugin/plugin.json        # "skills": "./skills/"
├── .codex-plugin/plugin.json
├── gemini-extension.json
├── README.md
├── CHANGELOG.md
├── upstream-sources.json             # sync manifest (travels with the plugin)
└── skills/
    ├── gog/
    ├── acpx/
    ├── meme-maker/
    ├── agent-transcript/
    ├── autoreview/
    ├── handoff/
    └── session-viewer/
```

Each `skills/<name>/` directory contains the **verbatim upstream folder** plus
exactly one dendrite-local file: `agents/openai.yaml` (the OpenAI companion that
every skill with a `SKILL.md` must have). `agents/openai.yaml` is the only file
the sync tool must preserve across an `--apply`.

Plugin-level README/CHANGELOG are dendrite-authored (required per-plugin by
`check-plugin-docs`, minimum 3 non-blank lines each). Per-skill README/CHANGELOG
are **not** required by dendrite; whatever the upstream folder ships comes along
verbatim.

Both marketplace manifests gain one `upstream-skills` entry:
- `.claude-plugin/marketplace.json` — `{ name, source: "./plugins/upstream-skills", description }`
- `.agents/plugins/marketplace.json` — the richer object form (source/policy/
  category/interface), matching the shape of existing entries.

There are no MCP servers in this plugin, so nothing is added to
`NO_MCP_REF_NAMES`; the no-MCP transform handles it with no special-casing.

## Manifest — `plugins/upstream-skills/upstream-sources.json`

```json
{
  "skills": [
    {
      "name": "gog",
      "repo": "openclaw/gogcli",
      "branch": "main",
      "src_path": ".agents/skills/gog",
      "pinned_sha": "<40-char commit SHA>",
      "content_hash": "sha256:<hex>",
      "local_only": ["agents/openai.yaml"]
    }
  ]
}
```

- `dest_path` is derived: `plugins/upstream-skills/skills/<name>`.
- `content_hash` is computed over **upstream-owned files only** (every file under
  the vendored skill folder *except* the `local_only` paths). It is a
  deterministic fingerprint: sha256 over a sorted list of
  `(relative_path, sha256(file_bytes))` pairs, so order, content, additions, and
  deletions all affect the hash.
- `local_only` lists files the tool must never overwrite or delete on apply.

## Tool — `plugins/scripts/sync-upstream-skills`

Python 3 (consistent with the existing `check-*` scripts), executable bit set,
no third-party deps. Uses `gh` for GitHub access (auth + rate-limit headroom)
and the stdlib for hashing/tar extraction.

### `add <github-url>` (network) — the onboarding command

The whole point of the minimal-config principle. Given one GitHub folder/file
URL:

1. Parse the URL into `owner/repo`, `ref`, and `src_path` (see Minimal-config
   principle). Derive `name` from the last path segment.
2. Reject if a skill with that `name` already exists in the manifest (or
   `--force` to re-add).
3. Resolve the target SHA at `ref` for that path, download the tarball, and
   extract `src_path` into `plugins/upstream-skills/skills/<name>/`.
4. **Auto-generate `skills/<name>/agents/openai.yaml`** from the vendored
   `SKILL.md` frontmatter: `display_name` from `name`, `short_description` from
   `description` (truncated), `default_prompt` a simple "Use <name> to …" line.
   Only written if absent (it is a `local_only` file, so it survives later
   applies and can be hand-tuned).
5. Append the entry to `upstream-sources.json` with `pinned_sha` +
   `content_hash`.
6. Print: skill added; reminder to review `git diff` and run `check-all`.

After `add`, the skill is fully wired for sync. The user touched nothing but the
URL.

### `--check` (network)

For each skill in the manifest:

1. **Local integrity.** Recompute the content hash of the vendored upstream-owned
   files. If it differs from `content_hash`, report **LOCAL DRIFT** — the
   vendored copy was hand-edited or a prior apply was incomplete.
2. **Upstream update.** Resolve the branch tip and download the upstream subtree
   at that tip (see Fetch). Compute its content hash. If it differs from
   `content_hash`, report **UPDATE AVAILABLE**, showing `pinned_sha -> tip_sha`.
   Because the hash covers the whole subtree, this fires for any changed/added/
   removed file under the folder, not just `SKILL.md`.

Prints a per-skill status table. Exits non-zero if any skill shows either drift
kind. Flags: `--check` (default), optional skill-name filters.

### `--apply [name…|--all]`

For each targeted skill:

1. Resolve the target SHA: the branch tip (or `--sha <sha>` override).
2. Download the repo tarball at that SHA via `gh api repos/{repo}/tarball/{sha}`
   and extract only `src_path`.
3. Replace all upstream-owned files in `dest` (delete everything except
   `local_only`, then copy the freshly extracted upstream files in). This makes
   deletions upstream propagate.
4. Preserve `local_only` files untouched. If `agents/openai.yaml` is missing,
   regenerate the stub from the freshly vendored `SKILL.md` frontmatter (same
   generator `add` uses), so the dendrite invariant is never left broken.
5. Recompute `content_hash`, update `pinned_sha` + `content_hash` in the manifest.
6. Print a summary. The human runs `git diff`, sanity-checks, and commits.

### Fetch mechanism

Tarball-at-SHA (`gh api repos/{repo}/tarball/{sha}` → extract subpath). No full
clones; works for any commit; trivial to hash. Branch-tip resolution for
`--check` uses `gh api repos/{repo}/commits/{branch}` (or `git ls-remote`).

## Workflow

**One-time plugin scaffolding** (done once, not per skill):
- Author plugin manifests (`.claude-plugin/plugin.json`,
  `.codex-plugin/plugin.json`, `gemini-extension.json`), README, CHANGELOG. The
  Claude/Codex manifests use `"skills": "./skills/"`, so new skill folders need
  no manifest edits.
- Add the `upstream-skills` entry to both marketplace manifests.

**Onboarding the seven skills** — paste each URL:
```
sync-upstream-skills add https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md
sync-upstream-skills add https://github.com/openclaw/acpx/blob/main/skills/acpx/SKILL.md
sync-upstream-skills add https://github.com/openclaw/openclaw/tree/main/skills/meme-maker
sync-upstream-skills add https://github.com/openclaw/agent-skills/tree/main/skills/agent-transcript
sync-upstream-skills add https://github.com/openclaw/agent-skills/tree/main/skills/autoreview
sync-upstream-skills add https://github.com/openclaw/agent-skills/tree/main/skills/handoff
sync-upstream-skills add https://github.com/openclaw/agent-skills/tree/main/skills/session-viewer
```
Each `add` vendors the folder, generates the `openai.yaml` stub, and records the
manifest entry. Then run `generate-docs` and `check-all` once to fold the plugin
into the matrices/README inventory and confirm all invariants pass.

**Ongoing sync:**
- `sync-upstream-skills --check` reports drift.
- `sync-upstream-skills --apply <name>` (or `--all`) pulls updates; review +
  commit.

**Adding a future skill:** one `sync-upstream-skills add <url>`, then
`check-all`. Nothing else.

## Module boundaries

- **Manifest** (`upstream-sources.json`): declarative source-of-truth for what is
  vendored and from where. Owned by the plugin, edited by the tool's `--apply`.
- **Sync tool** (`sync-upstream-skills`): the only thing that reads the manifest
  to fetch/compare/replace. Pure I/O around GitHub + filesystem + hashing; no
  knowledge of dendrite invariants beyond `local_only`.
- **Dendrite invariants** (existing `check-*` / `generate-docs`): unchanged. They
  treat the vendored skills like any other plugin's skills.

The tool depends on `gh` and the manifest; nothing depends on the tool's
internals. The manifest's `local_only` is the single contract that keeps dendrite
adaptations (`agents/openai.yaml`) from being clobbered.

## Out of scope

- Scheduled CI drift workflow (can be added later, mirroring
  `check-no-mcp-drift.yml`).
- Bidirectional sync / pushing changes back upstream (pull-only).
- Auto-creating the *plugin* scaffolding (manifests/README/marketplace entries)
  — that is a one-time manual setup; only per-skill onboarding is automated.
- Upstream branches whose ref contains a slash — those need a manual manifest
  edit (not expected for the current seven sources).
