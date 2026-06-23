---
name: notebooklm
description: "This skill should be used when the user mentions NotebookLM, says /notebooklm, or asks to create a podcast, generate an audio overview, make a quiz, summarize URLs, add sources to NotebookLM, generate flashcards, create a mind map, make an infographic, or download generated content. Covers full programmatic access to Google NotebookLM including features unavailable in the web UI."
---

# NotebookLM Automation

Complete programmatic access to Google NotebookLM, including capabilities not exposed in the web UI. Create notebooks, add sources (URLs, YouTube, PDFs, audio, video, images), chat with content, generate artifact types, and download results in multiple formats.

## Installation

**From PyPI (Recommended):**
```bash
pip install notebooklm-py
```

**From GitHub (use latest release tag, NOT main branch):**
```bash
# Get the latest release tag (using curl)
LATEST_TAG=$(curl -s https://api.github.com/repos/teng-lin/notebooklm-py/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
pip install "git+https://github.com/teng-lin/notebooklm-py@${LATEST_TAG}"
```

⚠️ **DO NOT install from main branch** (`pip install git+https://github.com/teng-lin/notebooklm-py`). The main branch may contain unreleased/unstable changes. Always use PyPI or a specific release tag, unless you are testing unreleased features.

## Prerequisites

**IMPORTANT:** Before using any command, you MUST authenticate:

```bash
notebooklm login          # Opens browser for Google OAuth
notebooklm list           # Verify authentication works
```

If commands fail with authentication errors, re-run `notebooklm login`.

### CI/CD, Multiple Accounts, and Parallel Agents

For automated environments, multiple accounts, or parallel agent workflows:

| Variable | Purpose |
|----------|---------|
| `NOTEBOOKLM_HOME` | Custom config directory (default: `~/.notebooklm`) |
| `NOTEBOOKLM_PROFILE` | Active profile name (default: `default`) |
| `NOTEBOOKLM_AUTH_JSON` | Inline auth JSON - no file writes needed |

**CI/CD setup:** Set `NOTEBOOKLM_AUTH_JSON` from a secret containing your `storage_state.json` contents.

**Multiple accounts:** Use named profiles (`notebooklm profile create work`, then `notebooklm -p work login`). Alternatively, use different `NOTEBOOKLM_HOME` directories per account.

**Parallel agents:** The CLI stores notebook context in a shared file (`~/.notebooklm/context.json`). Multiple concurrent agents using `notebooklm use` can overwrite each other's context.

**Solutions for parallel workflows:**
1. **Always use explicit notebook ID** (recommended): Pass `-n <notebook_id>` (for `wait`/`download` commands) or `--notebook <notebook_id>` (for others) instead of relying on `use`
2. **Per-agent isolation via profiles:** `export NOTEBOOKLM_PROFILE=agent-$ID` (each profile gets its own context file)
3. **Per-agent isolation via home:** Set unique `NOTEBOOKLM_HOME` per agent: `export NOTEBOOKLM_HOME=/tmp/agent-$ID`
4. **Use full UUIDs:** Avoid partial IDs in automation (they can become ambiguous)

## Agent Setup Verification

Before starting workflows, verify the CLI is ready:

1. `notebooklm status` → Should show "Authenticated as: email@..."
2. `notebooklm list --json` → Should return valid JSON (even if empty notebooks list)
3. If either fails → Run `notebooklm login`

## Autonomy Rules

**The `wait` rule (resolves the only ambiguous case):** A `wait` command
(`artifact wait`, `source wait`, `research wait`) is fine to run **without
confirmation when it runs in a background agent/job** that polls an
already-started task. It needs **confirmation when run inline in the main
conversation**, because it blocks the conversation for the full generation
window. Default to delegating waits to a background worker; only block inline if
the user explicitly asked for a blocking workflow.

**Run automatically (no confirmation):**
- `notebooklm status` / `auth check` / `doctor` - diagnostics
- `notebooklm list` / `source list` / `artifact list` / `history` - read-only listings
- `notebooklm language list` / `language get` / `language set` - language config
- `notebooklm research status` - check research status
- `notebooklm artifact wait` / `source wait` / `research wait` - **only in a background/automation context** (see the `wait` rule above)
- `notebooklm use <id>` - set context (⚠️ SINGLE-AGENT ONLY - use `-n` flag in parallel workflows)
- `notebooklm create` - create notebook
- `notebooklm source add` - add sources
- `notebooklm ask "..."` - chat queries (without `--save-as-note`)
- `notebooklm profile list` / `profile create` / `profile switch` - profile management

**Ask before running:**
- `notebooklm delete` - destructive
- `notebooklm generate *` - long-running, may fail
- `notebooklm download *` - writes to filesystem
- `notebooklm artifact wait` / `source wait` / `research wait` - **only when run inline in the main conversation** (see the `wait` rule above)
- `notebooklm ask "..." --save-as-note` - writes a note
- `notebooklm history --save` - writes a note

## Quick Reference

For a complete command reference, see `references/quick-reference.md`. Detailed
tables (generation types and options, language codes, JSON schemas, exit codes)
and step-by-step workflows live in `references/reference.md`.

## Core command surface

Day-to-day commands (full table in `references/quick-reference.md`):

- **Notebooks:** `create "Title"`, `list`, `use <id>` (single-agent), `notebook delete <id>`
- **Sources:** `source add <url|file>`, `source list`, `source wait <id>`, `source fulltext <id>`, `source add-research "query" [--mode deep]`
- **Chat:** `ask "question"` (add `--json` for citations, `--save-as-note` to persist)
- **Generate:** `generate <audio|video|slide-deck|infographic|report|mind-map|data-table|quiz|flashcards> [...]` — returns a `task_id`
- **Artifacts:** `artifact list`, `artifact wait <id>`, `download <type> <path>`
- **Research:** `research status`, `research wait --import-all`
- **Config:** `language set <code>`, `profile create/switch`, `doctor`

`--json` is available on most commands for machine-readable output. Generation,
download, exit codes, JSON schemas, language codes, processing times, and
step-by-step workflows are documented in `references/reference.md`.

## Output Style

**Progress updates:** Brief status for each step
- "Creating notebook 'Research: AI'..."
- "Adding source: https://example.com..."
- "Starting audio generation... (task ID: abc123)"

**Fire-and-forget for long operations:**
- Start generation, return artifact ID immediately
- Do NOT poll or wait in main conversation - generation takes 5-45 minutes (see timing table)
- User checks status manually, OR use a background worker with `artifact wait`

**JSON output:** Most commands accept `--json` for machine-readable output
(`list`, `auth check`, `source list`, `artifact list`, `generate`, `ask`, ...).
Field-level schemas and status-value meanings are in `references/reference.md`.

## Error Handling

**On failure, offer the user a choice:**
1. Retry the operation
2. Skip and continue with something else
3. Investigate the error

**Error decision tree:**

| Error | Cause | Action |
|-------|-------|--------|
| Auth/cookie error | Session expired | Run `notebooklm auth check` then `notebooklm login` |
| "No notebook context" | Context not set | Use `-n <id>` or `--notebook <id>` flag (parallel), or `notebooklm use <id>` (single-agent) |
| "No result found for RPC ID" | Rate limiting | Wait 5-10 min, retry |
| `GENERATION_FAILED` | Google rate limit | Wait and retry later |
| Download fails | Generation incomplete | Check `artifact list` for status |
| Invalid notebook/source ID | Wrong ID | Run `notebooklm list` to verify |
| RPC protocol error | Google changed APIs | May need CLI update |

**Exit codes:** `0` success, `1` error (not found / processing failed), `2`
timeout (wait commands only). Full breakdown in `references/reference.md`.

## Known Limitations

**Rate limiting:** Audio, video, quiz, flashcards, infographic, and slide deck generation may fail due to Google's rate limits. This is an API limitation, not a bug.

**Reliable operations:** These always work:
- Notebooks (list, create, delete, rename)
- Sources (add, list, delete)
- Chat/queries
- Mind-map, study-guide, report, data-table generation

**Unreliable operations:** These may fail with rate limiting:
- Audio (podcast) generation
- Video generation
- Quiz and flashcard generation
- Infographic and slide deck generation

**Workaround:** If generation fails:
1. Check status: `notebooklm artifact list`
2. Retry after 5-10 minutes
3. Use the NotebookLM web UI as fallback

**Processing times vary significantly** (source processing 30s–10min, deep
research 15–30+min, audio 10–20min, video 15–45min). Use background execution
for long operations and poll every 15–30s when checking status manually. Full
timing/timeout table is in `references/reference.md`.

**Language** is a **GLOBAL** account setting (`notebooklm language set <code>`,
e.g. `ja`, `zh_Hans`), overridable per generate command with `--language`. Code
list and offline `--local` usage are in `references/reference.md`.

## Troubleshooting

```bash
notebooklm --help              # Main commands
notebooklm auth check          # Diagnose auth issues
notebooklm auth check --test   # Full auth validation with network test
notebooklm notebook --help     # Notebook management
notebooklm source --help       # Source management
notebooklm research --help     # Research status/wait
notebooklm generate --help     # Content generation
notebooklm artifact --help     # Artifact management
notebooklm download --help     # Download content
notebooklm language --help     # Language settings
```

**Diagnose auth:** `notebooklm auth check` - shows cookie domains, storage path, validation status
**Re-authenticate:** `notebooklm login`
**Check version:** `notebooklm --version`
**Update an outdated CLI:** reinstall the latest release per the *Installation*
section above (`pip install -U notebooklm-py`). If the CLI provides a
`notebooklm skill install` subcommand for refreshing its bundled skill files,
run that after upgrading; otherwise the pip upgrade is sufficient.
