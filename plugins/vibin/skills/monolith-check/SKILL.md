---
name: monolith-check
description: "Use this skill when the user asks to check source files against the monolith policy, find oversized files, audit Rust function size, run a whole-repo monolith report, or verify staged changes stay under file/function size limits."
---

# Monolith Check

Use this skill to enforce the repository monolith policy:

- Source files should stay under 500 effective lines.
- Rust functions warn above 80 effective lines.
- Rust functions fail above 120 effective lines.
- Allowlist entries in `.monolith-allowlist` are temporary and checked for expiry.

`<skill-dir>` in the commands below is this skill's own directory — the
directory containing this `SKILL.md` (its `scripts/enforce_monoliths.py` ships
with the skill). Resolve it before running, e.g. `SKILL_DIR="$(dirname
"$0")"`-style, or just substitute the absolute path of this skill directory.
The `--staged`, `--file`, and `--base/--head` checks read tracked files and the
host repo's `.monolith-allowlist` from the current working directory, so run
them from the repo root being audited.

## Commands

Run against staged changes:

```bash
python3 <skill-dir>/scripts/enforce_monoliths.py --staged
```

Run against one file:

```bash
python3 <skill-dir>/scripts/enforce_monoliths.py --file crates/jobs/crawl_jobs.rs
```

Run against a base/head diff:

```bash
python3 <skill-dir>/scripts/enforce_monoliths.py --base origin/main --head HEAD
```

Generate a whole-repo report:

```bash
python3 <skill-dir>/scripts/enforce_monoliths.py --whole-repo
```

Include already allowlisted files in the report:

```bash
python3 <skill-dir>/scripts/enforce_monoliths.py --whole-repo --include-allowlisted
```

Run the detector self-test:

```bash
python3 <skill-dir>/scripts/enforce_monoliths.py --self-test
```

## Workflow

1. Resolve `<skill-dir>` to this skill directory.
2. Run the narrowest check that matches the request.
3. If the script reports violations, prefer splitting code into focused files or functions.
4. Do not add new allowlist entries unless the user explicitly asks and the exception is justified.
5. Report exact files/functions, line counts, and the command you ran.
