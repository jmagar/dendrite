# Upstream Skills Vendoring + Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vendor 11 upstream skill folders into a new `upstream-skills` marketplace plugin and ship a `sync-upstream-skills` tool that onboards a skill from a single GitHub URL and detects/applies upstream drift.

**Architecture:** A new plugin `plugins/upstream-skills/` holds each skill as a verbatim upstream folder plus one dendrite-local file (`agents/openai.yaml`). A `plugins/scripts/sync-upstream-skills` Python tool reads a JSON manifest (`upstream-sources.json`) describing each skill's source repo/ref/path/pinned-SHA/content-hash, and provides `add`, `check`, and `apply` subcommands. Drift is detected by a content hash over the entire skill subtree (every upstream-owned file), so changes to references/scripts/added/deleted files are all caught.

**Tech Stack:** Python 3 (stdlib only for the tool: `argparse`, `hashlib`, `json`, `re`, `subprocess`, `tarfile`, `io`, `tempfile`, `shutil`, `pathlib`). Tests use stdlib `unittest`. `gh` CLI for GitHub access. `jsonschema` (already a repo dependency) for the manifest schema, validated through the existing `validate-plugin-schemas`.

## Global Constraints

- Tool is stdlib-only — no third-party imports in `plugins/scripts/sync-upstream-skills`.
- Always vendor the **entire** skill folder, never just `SKILL.md`.
- `agents/openai.yaml` is the only dendrite-local per-skill file; `apply` must preserve it byte-for-byte (regenerate only if missing).
- The tool never creates a git commit.
- Drift signal is a content hash over all upstream-owned files (excludes `local_only`); order-independent; sensitive to content, additions, and deletions.
- Manifest path: `plugins/upstream-skills/upstream-sources.json`. Manifest must always validate against `plugins/schemas/upstream-sources.schema.json`.
- Python scripts use `#!/usr/bin/env python3` and `from __future__ import annotations`, matching existing `plugins/scripts/*` style.
- Preserve executable bits on the new tool.
- `name` slug pattern: `^[a-z0-9][a-z0-9-]*$`. `repo`: `owner/repo`. `pinned_sha`: 40 hex. `content_hash`: `sha256:` + 64 hex.

---

## File Structure

- Create `plugins/scripts/sync-upstream-skills` — the tool (importable functions + `main()`), executable.
- Create `plugins/scripts/tests/test_sync_upstream_skills.py` — `unittest` suite (loads the tool via `SourceFileLoader`).
- Create `plugins/schemas/upstream-sources.schema.json` — manifest data contract.
- Modify `plugins/scripts/validate-plugin-schemas` — validate the manifest against the schema.
- Modify `plugins/scripts/check-all` — run the unit tests.
- Create `plugins/upstream-skills/.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `README.md`, `CHANGELOG.md`, `upstream-sources.json`.
- Generated (not hand-written): `plugins/upstream-skills/gemini-extension.json` (via `generate-gemini-extensions`).
- Modify `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json` — add the `upstream-skills` entry.
- Created by the tool: `plugins/upstream-skills/skills/<name>/...` for all 11 skills.

---

### Task 1: Tool skeleton + URL parsing

**Files:**
- Create: `plugins/scripts/sync-upstream-skills`
- Test: `plugins/scripts/tests/test_sync_upstream_skills.py`

**Interfaces:**
- Produces: `parse_skill_url(url: str) -> dict` returning keys `{"name", "repo", "branch", "src_path"}`. Raises `ValueError` on a non-GitHub tree/blob URL.

- [ ] **Step 1: Write the failing test**

Create `plugins/scripts/tests/test_sync_upstream_skills.py`:

```python
import importlib.machinery
import importlib.util
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1] / "sync-upstream-skills"
_loader = importlib.machinery.SourceFileLoader("sync_upstream_skills", str(TOOL))
_spec = importlib.util.spec_from_loader("sync_upstream_skills", _loader)
sus = importlib.util.module_from_spec(_spec)
_loader.exec_module(sus)


class TestParseSkillUrl(unittest.TestCase):
    def test_tree_url(self):
        got = sus.parse_skill_url(
            "https://github.com/openclaw/openclaw/tree/main/skills/meme-maker"
        )
        self.assertEqual(got, {
            "name": "meme-maker",
            "repo": "openclaw/openclaw",
            "branch": "main",
            "src_path": "skills/meme-maker",
        })

    def test_blob_url_strips_skill_md(self):
        got = sus.parse_skill_url(
            "https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md"
        )
        self.assertEqual(got["src_path"], ".agents/skills/gog")
        self.assertEqual(got["name"], "gog")

    def test_dot_prefixed_parent_segment(self):
        got = sus.parse_skill_url(
            "https://github.com/openai/skills/tree/main/skills/.curated/yeet"
        )
        self.assertEqual(got["src_path"], "skills/.curated/yeet")
        self.assertEqual(got["name"], "yeet")

    def test_rejects_non_github(self):
        with self.assertRaises(ValueError):
            sus.parse_skill_url("https://example.com/foo/bar")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: FAIL — `FileNotFoundError`/load error because `plugins/scripts/sync-upstream-skills` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `plugins/scripts/sync-upstream-skills`:

```python
#!/usr/bin/env python3
"""Vendor upstream skill folders into dendrite and keep them in sync."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLUGIN_DIR = ROOT / "plugins" / "upstream-skills"
SKILLS_DIR = PLUGIN_DIR / "skills"
MANIFEST_PATH = PLUGIN_DIR / "upstream-sources.json"
DEFAULT_LOCAL_ONLY = ["agents/openai.yaml"]

_URL_RE = re.compile(
    r"^https?://github\.com/"
    r"(?P<owner>[^/]+)/(?P<repo>[^/]+)/"
    r"(?P<kind>tree|blob)/(?P<ref>[^/]+)/(?P<path>.+)$"
)


def parse_skill_url(url: str) -> dict:
    match = _URL_RE.match(url.strip())
    if not match:
        raise ValueError(f"Not a GitHub tree/blob URL: {url}")
    path = match["path"].rstrip("/")
    if match["kind"] == "blob":
        if path.endswith("/SKILL.md"):
            path = path[: -len("/SKILL.md")]
        else:
            path = path.rsplit("/", 1)[0]
    return {
        "name": path.rsplit("/", 1)[-1],
        "repo": f"{match['owner']}/{match['repo']}",
        "branch": match["ref"],
        "src_path": path,
    }
```

Make it executable:

```bash
chmod +x plugins/scripts/sync-upstream-skills
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: PASS (4 tests in `TestParseSkillUrl`).

- [ ] **Step 5: Commit**

```bash
git add plugins/scripts/sync-upstream-skills plugins/scripts/tests/test_sync_upstream_skills.py
git commit -m "feat(upstream-skills): tool skeleton + GitHub URL parsing"
```

---

### Task 2: Content hash over the skill subtree

**Files:**
- Modify: `plugins/scripts/sync-upstream-skills`
- Test: `plugins/scripts/tests/test_sync_upstream_skills.py`

**Interfaces:**
- Produces: `compute_content_hash(skill_dir: Path, local_only: list[str]) -> str` returning `"sha256:<64 hex>"`. Hash is over every file under `skill_dir` except the `local_only` relative paths; order-independent; sensitive to content/additions/deletions.

- [ ] **Step 1: Write the failing test**

Append to the test file (before the `if __name__` line):

```python
import tempfile


class TestContentHash(unittest.TestCase):
    def _make(self, root, files):
        for rel, data in files.items():
            p = root / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(data)

    def test_order_independent_and_deterministic(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            ra, rb = Path(a), Path(b)
            self._make(ra, {"SKILL.md": "x", "references/r.md": "y"})
            self._make(rb, {"references/r.md": "y", "SKILL.md": "x"})
            self.assertEqual(
                sus.compute_content_hash(ra, []),
                sus.compute_content_hash(rb, []),
            )

    def test_content_change_changes_hash(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            ra, rb = Path(a), Path(b)
            self._make(ra, {"SKILL.md": "x", "scripts/s.sh": "echo 1"})
            self._make(rb, {"SKILL.md": "x", "scripts/s.sh": "echo 2"})
            self.assertNotEqual(
                sus.compute_content_hash(ra, []),
                sus.compute_content_hash(rb, []),
            )

    def test_added_file_changes_hash(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            ra, rb = Path(a), Path(b)
            self._make(ra, {"SKILL.md": "x"})
            self._make(rb, {"SKILL.md": "x", "references/new.md": "z"})
            self.assertNotEqual(
                sus.compute_content_hash(ra, []),
                sus.compute_content_hash(rb, []),
            )

    def test_local_only_excluded(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            ra, rb = Path(a), Path(b)
            self._make(ra, {"SKILL.md": "x"})
            self._make(rb, {"SKILL.md": "x", "agents/openai.yaml": "interface: {}"})
            self.assertEqual(
                sus.compute_content_hash(ra, ["agents/openai.yaml"]),
                sus.compute_content_hash(rb, ["agents/openai.yaml"]),
            )

    def test_hash_format(self):
        with tempfile.TemporaryDirectory() as a:
            ra = Path(a)
            self._make(ra, {"SKILL.md": "x"})
            digest = sus.compute_content_hash(ra, [])
            self.assertRegex(digest, r"^sha256:[0-9a-f]{64}$")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: FAIL — `AttributeError: module 'sync_upstream_skills' has no attribute 'compute_content_hash'`.

- [ ] **Step 3: Write minimal implementation**

Add `import hashlib` to the imports, then add:

```python
def compute_content_hash(skill_dir: Path, local_only: list[str]) -> str:
    excluded = {(skill_dir / rel).resolve() for rel in local_only}
    entries: list[tuple[str, str]] = []
    for path in skill_dir.rglob("*"):
        if not path.is_file() or path.resolve() in excluded:
            continue
        rel = path.relative_to(skill_dir).as_posix()
        entries.append((rel, hashlib.sha256(path.read_bytes()).hexdigest()))
    entries.sort()
    outer = hashlib.sha256()
    for rel, digest in entries:
        outer.update(f"{rel}\0{digest}\n".encode())
    return "sha256:" + outer.hexdigest()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: PASS (all `TestContentHash` tests).

- [ ] **Step 5: Commit**

```bash
git add plugins/scripts/sync-upstream-skills plugins/scripts/tests/test_sync_upstream_skills.py
git commit -m "feat(upstream-skills): content hash over skill subtree"
```

---

### Task 3: openai.yaml stub generation from SKILL.md frontmatter

**Files:**
- Modify: `plugins/scripts/sync-upstream-skills`
- Test: `plugins/scripts/tests/test_sync_upstream_skills.py`

**Interfaces:**
- Produces: `parse_frontmatter(text: str) -> dict` (top-level `key: value` scalars in the leading `---` block) and `generate_openai_yaml(skill_md_text: str, name: str) -> str` (a valid `interface:` YAML document).

- [ ] **Step 1: Write the failing test**

Append to the test file:

```python
class TestOpenaiYaml(unittest.TestCase):
    SKILL = (
        "---\n"
        'name: meme-maker\n'
        'description: Make memes from templates with captions.\n'
        "---\n\n# Meme Maker\n"
    )

    def test_frontmatter_parsed(self):
        fm = sus.parse_frontmatter(self.SKILL)
        self.assertEqual(fm["name"], "meme-maker")
        self.assertEqual(fm["description"], "Make memes from templates with captions.")

    def test_generates_interface_block(self):
        out = sus.generate_openai_yaml(self.SKILL, "meme-maker")
        self.assertIn("interface:", out)
        self.assertIn("display_name:", out)
        self.assertIn("short_description:", out)
        self.assertIn("default_prompt:", out)

    def test_no_frontmatter_falls_back_to_name(self):
        out = sus.generate_openai_yaml("# no frontmatter here", "yeet")
        self.assertIn("Yeet", out)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: FAIL — `AttributeError: ... has no attribute 'parse_frontmatter'`.

- [ ] **Step 3: Write minimal implementation**

Add:

```python
def parse_frontmatter(text: str) -> dict:
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    data: dict = {}
    for line in text[3:end].splitlines():
        if not line or line[0].isspace() or ":" not in line:
            continue
        key, _, value = line.partition(":")
        data[key.strip()] = value.strip().strip('"').strip("'")
    return data


def _yaml_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def generate_openai_yaml(skill_md_text: str, name: str) -> str:
    fm = parse_frontmatter(skill_md_text)
    display = fm.get("name", name).replace("-", " ").replace("_", " ").title()
    description = fm.get("description", "").strip()
    if len(description) > 120:
        short = description[:117].rstrip() + "..."
    else:
        short = description or f"{display} skill."
    prompt = f"Use {name}: {short}" if description else f"Use {name}."
    return (
        "interface:\n"
        f"  display_name: {_yaml_quote(display)}\n"
        f"  short_description: {_yaml_quote(short)}\n"
        f"  default_prompt: {_yaml_quote(prompt)}\n"
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/scripts/sync-upstream-skills plugins/scripts/tests/test_sync_upstream_skills.py
git commit -m "feat(upstream-skills): generate openai.yaml stub from frontmatter"
```

---

### Task 4: Manifest I/O + data-contract schema + validator wiring

**Files:**
- Create: `plugins/schemas/upstream-sources.schema.json`
- Modify: `plugins/scripts/sync-upstream-skills`
- Modify: `plugins/scripts/validate-plugin-schemas`
- Test: `plugins/scripts/tests/test_sync_upstream_skills.py`

**Interfaces:**
- Produces: `load_manifest() -> dict` (returns `{"skills": []}` if the file is absent) and `save_manifest(data: dict) -> None` (writes `skills` sorted by `name`, 2-space indent, trailing newline).

- [ ] **Step 1: Write the failing test**

Append to the test file:

```python
import json


class TestManifestIO(unittest.TestCase):
    def test_roundtrip_sorted(self):
        with tempfile.TemporaryDirectory() as d:
            sus.MANIFEST_PATH = Path(d) / "upstream-sources.json"
            sus.save_manifest({"skills": [
                {"name": "zeta"}, {"name": "alpha"},
            ]})
            data = sus.load_manifest()
            self.assertEqual([s["name"] for s in data["skills"]], ["alpha", "zeta"])

    def test_missing_file_is_empty(self):
        with tempfile.TemporaryDirectory() as d:
            sus.MANIFEST_PATH = Path(d) / "nope.json"
            self.assertEqual(sus.load_manifest(), {"skills": []})


class TestManifestSchema(unittest.TestCase):
    def setUp(self):
        from jsonschema import Draft7Validator
        schema_path = (
            Path(__file__).resolve().parents[2]
            / "schemas" / "upstream-sources.schema.json"
        )
        self.validator = Draft7Validator(json.loads(schema_path.read_text()))

    def _entry(self, **over):
        entry = {
            "name": "gog",
            "repo": "openclaw/gogcli",
            "branch": "main",
            "src_path": ".agents/skills/gog",
            "pinned_sha": "a" * 40,
            "content_hash": "sha256:" + "b" * 64,
            "local_only": ["agents/openai.yaml"],
        }
        entry.update(over)
        return entry

    def test_valid_manifest_passes(self):
        errors = list(self.validator.iter_errors({"skills": [self._entry()]}))
        self.assertEqual(errors, [])

    def test_bad_sha_rejected(self):
        bad = self._entry(pinned_sha="xyz")
        self.assertTrue(list(self.validator.iter_errors({"skills": [bad]})))

    def test_missing_required_rejected(self):
        bad = self._entry()
        del bad["content_hash"]
        self.assertTrue(list(self.validator.iter_errors({"skills": [bad]})))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: FAIL — `save_manifest` missing and the schema file does not exist.

- [ ] **Step 3a: Create the schema**

Create `plugins/schemas/upstream-sources.schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://github.com/jmagar/dendrite/plugins/schemas/upstream-sources.schema.json",
  "title": "Dendrite upstream skills sync manifest",
  "type": "object",
  "additionalProperties": false,
  "required": ["skills"],
  "properties": {
    "skills": {
      "type": "array",
      "items": { "$ref": "#/definitions/skill" }
    }
  },
  "definitions": {
    "skill": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "name", "repo", "branch", "src_path",
        "pinned_sha", "content_hash", "local_only"
      ],
      "properties": {
        "name": { "type": "string", "pattern": "^[a-z0-9][a-z0-9-]*$" },
        "repo": { "type": "string", "pattern": "^[^/\\s]+/[^/\\s]+$" },
        "branch": { "type": "string", "minLength": 1 },
        "src_path": { "type": "string", "minLength": 1 },
        "pinned_sha": { "type": "string", "pattern": "^[0-9a-f]{40}$" },
        "content_hash": { "type": "string", "pattern": "^sha256:[0-9a-f]{64}$" },
        "local_only": { "type": "array", "items": { "type": "string" } }
      }
    }
  }
}
```

- [ ] **Step 3b: Add manifest I/O to the tool**

Add `import json` to the imports, then add:

```python
def load_manifest() -> dict:
    if MANIFEST_PATH.exists():
        return json.loads(MANIFEST_PATH.read_text())
    return {"skills": []}


def save_manifest(data: dict) -> None:
    data["skills"].sort(key=lambda skill: skill["name"])
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(data, indent=2) + "\n")
```

- [ ] **Step 3c: Wire the schema into validate-plugin-schemas**

In `plugins/scripts/validate-plugin-schemas`, after the line
`GEMINI_EXTENSION_SCHEMA = SCHEMAS / "gemini-extension.schema.json"` add:

```python
UPSTREAM_SOURCES_SCHEMA = SCHEMAS / "upstream-sources.schema.json"
```

After the `gemini_schema_errors()` function definition, add:

```python
def upstream_sources_errors() -> list[str]:
    manifest = ROOT / "plugins" / "upstream-skills" / "upstream-sources.json"
    if not manifest.exists():
        return []
    schema = load_local_schema(UPSTREAM_SOURCES_SCHEMA)
    return validate_json_schema(manifest, schema)
```

In `main()`, after the `gemini_schema_errors()` try/except block, add:

```python
    try:
        errors.extend(upstream_sources_errors())
    except Exception as exc:
        errors.append(f"Upstream sources validation failed before checking files: {exc}")
```

- [ ] **Step 4: Run tests + validator to verify they pass**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: PASS (manifest IO + schema tests).
Run: `plugins/scripts/validate-plugin-schemas`
Expected: `Plugin schema validation passed` (no manifest yet → no new errors).

- [ ] **Step 5: Commit**

```bash
git add plugins/schemas/upstream-sources.schema.json plugins/scripts/sync-upstream-skills plugins/scripts/validate-plugin-schemas plugins/scripts/tests/test_sync_upstream_skills.py
git commit -m "feat(upstream-skills): manifest IO + schema data contract"
```

---

### Task 5: Network helpers + fetch + apply_skill

**Files:**
- Modify: `plugins/scripts/sync-upstream-skills`
- Test: `plugins/scripts/tests/test_sync_upstream_skills.py`

**Interfaces:**
- Produces:
  - `_download_tarball(repo: str, sha: str) -> bytes` — raw `.tar.gz` bytes (calls `gh`); the seam tests monkeypatch.
  - `resolve_tip_sha(repo: str, branch: str, src_path: str) -> str` — latest commit SHA touching `src_path` (calls `gh`).
  - `fetch_subtree(repo: str, sha: str, src_path: str, dest: Path) -> None` — extracts only `src_path` from the tarball into `dest`, replacing `dest`.
  - `apply_skill(entry: dict) -> None` — preserves `local_only`, fetches the branch-tip subtree, restores `local_only`, regenerates `agents/openai.yaml` if missing, and updates `entry["pinned_sha"]` + `entry["content_hash"]` in place.

- [ ] **Step 1: Write the failing test**

Append to the test file:

```python
import io
import tarfile


def _make_tarball(prefix, files):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for rel, data in files.items():
            raw = data.encode()
            info = tarfile.TarInfo(name=f"{prefix}/{rel}")
            info.size = len(raw)
            tar.addfile(info, io.BytesIO(raw))
    return buf.getvalue()


class TestFetchSubtree(unittest.TestCase):
    def test_extracts_only_src_path(self):
        tarball = _make_tarball("openclaw-openclaw-abc123", {
            "skills/meme-maker/SKILL.md": "meme",
            "skills/meme-maker/scripts/run.sh": "echo hi",
            "skills/other/SKILL.md": "other",
            "README.md": "top",
        })
        orig = sus._download_tarball
        sus._download_tarball = lambda repo, sha: tarball
        try:
            with tempfile.TemporaryDirectory() as d:
                dest = Path(d) / "meme-maker"
                sus.fetch_subtree("openclaw/openclaw", "abc123",
                                  "skills/meme-maker", dest)
                self.assertEqual((dest / "SKILL.md").read_text(), "meme")
                self.assertEqual((dest / "scripts/run.sh").read_text(), "echo hi")
                self.assertFalse((dest / "other").exists())
        finally:
            sus._download_tarball = orig


class TestApplySkill(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        sus.SKILLS_DIR = Path(self.tmp.name) / "skills"
        self._orig_resolve = sus.resolve_tip_sha
        self._orig_fetch = sus.fetch_subtree

    def tearDown(self):
        sus.resolve_tip_sha = self._orig_resolve
        sus.fetch_subtree = self._orig_fetch
        self.tmp.cleanup()

    def _fake_fetch(self, files):
        def fetch(repo, sha, src_path, dest):
            import shutil
            if dest.exists():
                shutil.rmtree(dest)
            dest.mkdir(parents=True)
            for rel, data in files.items():
                p = dest / rel
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(data)
        return fetch

    def test_generates_openai_when_missing_and_sets_hashes(self):
        sus.resolve_tip_sha = lambda repo, branch, path: "c" * 40
        sus.fetch_subtree = self._fake_fetch({
            "SKILL.md": "---\nname: gog\ndescription: Do gog.\n---\n",
        })
        entry = {
            "name": "gog", "repo": "openclaw/gogcli", "branch": "main",
            "src_path": ".agents/skills/gog", "pinned_sha": "",
            "content_hash": "", "local_only": ["agents/openai.yaml"],
        }
        sus.apply_skill(entry)
        dest = sus.SKILLS_DIR / "gog"
        self.assertTrue((dest / "agents/openai.yaml").exists())
        self.assertEqual(entry["pinned_sha"], "c" * 40)
        self.assertRegex(entry["content_hash"], r"^sha256:[0-9a-f]{64}$")

    def test_preserves_existing_openai_and_propagates_deletion(self):
        dest = sus.SKILLS_DIR / "gog"
        (dest / "agents").mkdir(parents=True)
        (dest / "agents/openai.yaml").write_text("CUSTOM")
        (dest / "stale.md").write_text("old")
        sus.resolve_tip_sha = lambda repo, branch, path: "d" * 40
        sus.fetch_subtree = self._fake_fetch({"SKILL.md": "new"})
        entry = {
            "name": "gog", "repo": "openclaw/gogcli", "branch": "main",
            "src_path": ".agents/skills/gog", "pinned_sha": "",
            "content_hash": "", "local_only": ["agents/openai.yaml"],
        }
        sus.apply_skill(entry)
        self.assertEqual((dest / "agents/openai.yaml").read_text(), "CUSTOM")
        self.assertFalse((dest / "stale.md").exists())
        self.assertTrue((dest / "SKILL.md").exists())
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: FAIL — `_download_tarball`/`apply_skill` missing.

- [ ] **Step 3: Write minimal implementation**

Add to imports: `import io`, `import shutil`, `import subprocess`, `import tarfile`. Then add:

```python
def _download_tarball(repo: str, sha: str) -> bytes:
    result = subprocess.run(
        ["gh", "api", f"repos/{repo}/tarball/{sha}"],
        check=True, capture_output=True,
    )
    return result.stdout


def resolve_tip_sha(repo: str, branch: str, src_path: str) -> str:
    result = subprocess.run(
        ["gh", "api",
         f"repos/{repo}/commits?path={src_path}&sha={branch}&per_page=1"],
        check=True, capture_output=True, text=True,
    )
    commits = json.loads(result.stdout)
    if not commits:
        raise RuntimeError(f"No commits for {src_path} in {repo}@{branch}")
    return commits[0]["sha"]


def fetch_subtree(repo: str, sha: str, src_path: str, dest: Path) -> None:
    raw = _download_tarball(repo, sha)
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar:
        members = tar.getmembers()
        if not members:
            raise RuntimeError(f"Empty tarball for {repo}@{sha}")
        prefix = members[0].name.split("/", 1)[0] + "/"
        want = f"{prefix}{src_path.rstrip('/')}/"
        if dest.exists():
            shutil.rmtree(dest)
        dest.mkdir(parents=True)
        extracted = False
        for member in members:
            if not member.isfile() or not member.name.startswith(want):
                continue
            rel = member.name[len(want):]
            target = dest / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            source = tar.extractfile(member)
            target.write_bytes(source.read())
            extracted = True
        if not extracted:
            raise RuntimeError(f"No files under {src_path} in {repo}@{sha}")


def apply_skill(entry: dict) -> None:
    dest = SKILLS_DIR / entry["name"]
    preserved: dict[str, bytes] = {}
    for rel in entry["local_only"]:
        path = dest / rel
        if path.exists():
            preserved[rel] = path.read_bytes()
    sha = resolve_tip_sha(entry["repo"], entry["branch"], entry["src_path"])
    fetch_subtree(entry["repo"], sha, entry["src_path"], dest)
    for rel, data in preserved.items():
        path = dest / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    openai_path = dest / "agents" / "openai.yaml"
    if not openai_path.exists():
        skill_md = (dest / "SKILL.md").read_text()
        openai_path.parent.mkdir(parents=True, exist_ok=True)
        openai_path.write_text(generate_openai_yaml(skill_md, entry["name"]))
    entry["pinned_sha"] = sha
    entry["content_hash"] = compute_content_hash(dest, entry["local_only"])
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/scripts/sync-upstream-skills plugins/scripts/tests/test_sync_upstream_skills.py
git commit -m "feat(upstream-skills): fetch subtree + apply_skill"
```

---

### Task 6: `add` command

**Files:**
- Modify: `plugins/scripts/sync-upstream-skills`
- Test: `plugins/scripts/tests/test_sync_upstream_skills.py`

**Interfaces:**
- Produces: `add_skill(url: str, force: bool = False) -> dict` — parses the URL, refuses a duplicate `name` unless `force`, vendors via `apply_skill`, writes a schema-valid manifest entry, and returns the entry.

- [ ] **Step 1: Write the failing test**

Append to the test file:

```python
class TestAddSkill(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        sus.SKILLS_DIR = base / "skills"
        sus.MANIFEST_PATH = base / "upstream-sources.json"
        self._orig_resolve = sus.resolve_tip_sha
        self._orig_fetch = sus.fetch_subtree
        sus.resolve_tip_sha = lambda repo, branch, path: "e" * 40

        def fetch(repo, sha, src_path, dest):
            dest.mkdir(parents=True, exist_ok=True)
            (dest / "SKILL.md").write_text(
                "---\nname: gog\ndescription: Do gog.\n---\n"
            )
        sus.fetch_subtree = fetch

    def tearDown(self):
        sus.resolve_tip_sha = self._orig_resolve
        sus.fetch_subtree = self._orig_fetch
        self.tmp.cleanup()

    def test_add_writes_entry_and_openai(self):
        entry = sus.add_skill(
            "https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md"
        )
        self.assertEqual(entry["name"], "gog")
        data = sus.load_manifest()
        self.assertEqual([s["name"] for s in data["skills"]], ["gog"])
        self.assertTrue((sus.SKILLS_DIR / "gog/agents/openai.yaml").exists())

    def test_duplicate_rejected_without_force(self):
        url = "https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md"
        sus.add_skill(url)
        with self.assertRaises(SystemExit):
            sus.add_skill(url)

    def test_entry_validates_against_schema(self):
        from jsonschema import Draft7Validator
        schema_path = (
            Path(__file__).resolve().parents[2]
            / "schemas" / "upstream-sources.schema.json"
        )
        validator = Draft7Validator(json.loads(schema_path.read_text()))
        sus.add_skill(
            "https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md"
        )
        self.assertEqual(list(validator.iter_errors(sus.load_manifest())), [])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: FAIL — `add_skill` missing.

- [ ] **Step 3: Write minimal implementation**

Add:

```python
def add_skill(url: str, force: bool = False) -> dict:
    parsed = parse_skill_url(url)
    data = load_manifest()
    exists = any(skill["name"] == parsed["name"] for skill in data["skills"])
    if exists and not force:
        raise SystemExit(
            f"Skill '{parsed['name']}' already in manifest (use --force to re-add)"
        )
    entry = {
        **parsed,
        "pinned_sha": "",
        "content_hash": "",
        "local_only": list(DEFAULT_LOCAL_ONLY),
    }
    apply_skill(entry)
    data["skills"] = [s for s in data["skills"] if s["name"] != parsed["name"]]
    data["skills"].append(entry)
    save_manifest(data)
    return entry
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/scripts/sync-upstream-skills plugins/scripts/tests/test_sync_upstream_skills.py
git commit -m "feat(upstream-skills): add command"
```

---

### Task 7: `check` command

**Files:**
- Modify: `plugins/scripts/sync-upstream-skills`
- Test: `plugins/scripts/tests/test_sync_upstream_skills.py`

**Interfaces:**
- Produces: `check_skill(entry: dict) -> list[str]` returning a subset of `["LOCAL_DRIFT", "UPDATE_AVAILABLE"]` (empty list = in sync).

- [ ] **Step 1: Write the failing test**

Append to the test file:

```python
class TestCheckSkill(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        sus.SKILLS_DIR = Path(self.tmp.name) / "skills"
        self._orig_resolve = sus.resolve_tip_sha
        self._orig_fetch = sus.fetch_subtree

    def tearDown(self):
        sus.resolve_tip_sha = self._orig_resolve
        sus.fetch_subtree = self._orig_fetch
        self.tmp.cleanup()

    def _vendor(self, body):
        dest = sus.SKILLS_DIR / "gog"
        dest.mkdir(parents=True, exist_ok=True)
        (dest / "SKILL.md").write_text(body)
        return dest

    def _entry(self, content_hash):
        return {
            "name": "gog", "repo": "openclaw/gogcli", "branch": "main",
            "src_path": ".agents/skills/gog", "pinned_sha": "f" * 40,
            "content_hash": content_hash, "local_only": ["agents/openai.yaml"],
        }

    def _fake_upstream(self, body):
        def fetch(repo, sha, src_path, dest):
            dest.mkdir(parents=True, exist_ok=True)
            (dest / "SKILL.md").write_text(body)
        sus.fetch_subtree = fetch
        sus.resolve_tip_sha = lambda repo, branch, path: "0" * 40

    def test_in_sync(self):
        dest = self._vendor("same")
        digest = sus.compute_content_hash(dest, ["agents/openai.yaml"])
        self._fake_upstream("same")
        self.assertEqual(sus.check_skill(self._entry(digest)), [])

    def test_local_drift(self):
        self._vendor("edited-locally")
        self._fake_upstream("edited-locally")
        # recorded hash is for different content
        stale = "sha256:" + "0" * 64
        self.assertIn("LOCAL_DRIFT", sus.check_skill(self._entry(stale)))

    def test_update_available(self):
        dest = self._vendor("v1")
        digest = sus.compute_content_hash(dest, ["agents/openai.yaml"])
        self._fake_upstream("v2-new-references-too")
        self.assertIn("UPDATE_AVAILABLE", sus.check_skill(self._entry(digest)))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: FAIL — `check_skill` missing.

- [ ] **Step 3: Write minimal implementation**

Add `import tempfile` to the imports, then add:

```python
def check_skill(entry: dict) -> list[str]:
    statuses: list[str] = []
    dest = SKILLS_DIR / entry["name"]
    local_hash = (
        compute_content_hash(dest, entry["local_only"]) if dest.exists() else None
    )
    if local_hash != entry["content_hash"]:
        statuses.append("LOCAL_DRIFT")
    sha = resolve_tip_sha(entry["repo"], entry["branch"], entry["src_path"])
    with tempfile.TemporaryDirectory() as tmp:
        upstream_dir = Path(tmp) / entry["name"]
        fetch_subtree(entry["repo"], sha, entry["src_path"], upstream_dir)
        upstream_hash = compute_content_hash(upstream_dir, entry["local_only"])
    if upstream_hash != entry["content_hash"]:
        statuses.append("UPDATE_AVAILABLE")
    return statuses
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/scripts/sync-upstream-skills plugins/scripts/tests/test_sync_upstream_skills.py
git commit -m "feat(upstream-skills): check command"
```

---

### Task 8: CLI (`main`) wiring for add / check / apply

**Files:**
- Modify: `plugins/scripts/sync-upstream-skills`
- Test: `plugins/scripts/tests/test_sync_upstream_skills.py`

**Interfaces:**
- Produces: `main(argv: list[str] | None = None) -> int`. Subcommands: `add <url> [--force]`; `check` (exit 1 if any skill drifts, else 0); `apply [names…] [--all]` (re-vendors selected skills via `apply_skill` and saves the manifest).

- [ ] **Step 1: Write the failing test**

Append to the test file:

```python
class TestMainCheckExit(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        sus.SKILLS_DIR = base / "skills"
        sus.MANIFEST_PATH = base / "upstream-sources.json"
        self._orig_check = sus.check_skill

    def tearDown(self):
        sus.check_skill = self._orig_check
        self.tmp.cleanup()

    def _write_manifest(self):
        sus.save_manifest({"skills": [{
            "name": "gog", "repo": "openclaw/gogcli", "branch": "main",
            "src_path": ".agents/skills/gog", "pinned_sha": "a" * 40,
            "content_hash": "sha256:" + "b" * 64,
            "local_only": ["agents/openai.yaml"],
        }]})

    def test_check_clean_returns_zero(self):
        self._write_manifest()
        sus.check_skill = lambda entry: []
        self.assertEqual(sus.main(["check"]), 0)

    def test_check_drift_returns_one(self):
        self._write_manifest()
        sus.check_skill = lambda entry: ["UPDATE_AVAILABLE"]
        self.assertEqual(sus.main(["check"]), 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: FAIL — `main` missing.

- [ ] **Step 3: Write minimal implementation**

Add `import argparse` and `import sys` to the imports, then add:

```python
def _cmd_add(args) -> int:
    entry = add_skill(args.url, force=args.force)
    print(f"Added {entry['name']} @ {entry['pinned_sha'][:12]} "
          f"(review `git diff` and run plugins/scripts/check-all)")
    return 0


def _cmd_check(args) -> int:
    data = load_manifest()
    drifted = 0
    for entry in data["skills"]:
        statuses = check_skill(entry)
        label = ", ".join(statuses) if statuses else "ok"
        print(f"{entry['name']:<20} {label}")
        if statuses:
            drifted += 1
    if drifted:
        print(f"{drifted} skill(s) drifted", file=sys.stderr)
        return 1
    print("All upstream skills in sync")
    return 0


def _cmd_apply(args) -> int:
    data = load_manifest()
    names = {s["name"] for s in data["skills"]} if args.all else set(args.names)
    if not names:
        print("Nothing to apply (pass names or --all)", file=sys.stderr)
        return 1
    for entry in data["skills"]:
        if entry["name"] in names:
            apply_skill(entry)
            print(f"Applied {entry['name']} @ {entry['pinned_sha'][:12]}")
    save_manifest(data)
    print("Review `git diff` and commit.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Vendor upstream skill folders and keep them in sync."
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    add = sub.add_parser("add", help="Vendor a skill from a GitHub folder URL")
    add.add_argument("url")
    add.add_argument("--force", action="store_true")
    add.set_defaults(func=_cmd_add)

    check = sub.add_parser("check", help="Report drift (exit 1 if any)")
    check.set_defaults(func=_cmd_check)

    apply_p = sub.add_parser("apply", help="Pull upstream updates into vendored skills")
    apply_p.add_argument("names", nargs="*")
    apply_p.add_argument("--all", action="store_true")
    apply_p.set_defaults(func=_cmd_apply)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py -v`
Expected: PASS (whole suite green).
Run: `plugins/scripts/sync-upstream-skills --help`
Expected: usage text listing `add`, `check`, `apply`.

- [ ] **Step 5: Commit**

```bash
git add plugins/scripts/sync-upstream-skills plugins/scripts/tests/test_sync_upstream_skills.py
git commit -m "feat(upstream-skills): CLI add/check/apply"
```

---

### Task 9: Wire unit tests into check-all

**Files:**
- Modify: `plugins/scripts/check-all`

**Interfaces:**
- Consumes: `plugins/scripts/tests/test_sync_upstream_skills.py`.

- [ ] **Step 1: Add the test run to check-all**

In `plugins/scripts/check-all`, after the line
`plugins/scripts/validate-plugin-schemas`, add:

```bash
python3 plugins/scripts/tests/test_sync_upstream_skills.py
```

- [ ] **Step 2: Verify it runs**

Run: `python3 plugins/scripts/tests/test_sync_upstream_skills.py`
Expected: `OK` (tests pass; this is what check-all will invoke).

- [ ] **Step 3: Commit**

```bash
git add plugins/scripts/check-all
git commit -m "chore(upstream-skills): run sync tool tests in check-all"
```

---

### Task 10: Stand up the upstream-skills plugin and vendor all 11 skills

This task has one deliverable: a populated `upstream-skills` plugin that passes `check-all`. It requires network access (`gh` authenticated).

**Files:**
- Create: `plugins/upstream-skills/.claude-plugin/plugin.json`
- Create: `plugins/upstream-skills/.codex-plugin/plugin.json`
- Create: `plugins/upstream-skills/README.md`
- Create: `plugins/upstream-skills/CHANGELOG.md`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `.agents/plugins/marketplace.json`
- Generated: `plugins/upstream-skills/gemini-extension.json`, README inventory, docs.
- Created by the tool: `plugins/upstream-skills/skills/<name>/...` (11 skills) + `upstream-sources.json`.

**Interfaces:**
- Consumes: the `sync-upstream-skills add` command from Tasks 1–8.

- [ ] **Step 1: Author the Claude plugin manifest**

Create `plugins/upstream-skills/.claude-plugin/plugin.json`:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-plugin-manifest.json",
  "name": "upstream-skills",
  "description": "Skills vendored verbatim from upstream repos (openclaw + openai), kept in sync via sync-upstream-skills.",
  "skills": "./skills/",
  "author": {
    "name": "Jacob Magar",
    "email": "jmagar@users.noreply.github.com"
  },
  "repository": "https://github.com/jmagar/dendrite",
  "homepage": "https://github.com/jmagar/dendrite",
  "license": "MIT",
  "keywords": ["skills", "vendored", "upstream", "sync"]
}
```

- [ ] **Step 2: Author the Codex plugin manifest**

Create `plugins/upstream-skills/.codex-plugin/plugin.json`:

```json
{
  "name": "upstream-skills",
  "description": "Skills vendored verbatim from upstream repos (openclaw + openai), kept in sync via sync-upstream-skills.",
  "author": {
    "name": "Jacob Magar",
    "email": "jmagar@users.noreply.github.com"
  },
  "repository": "https://github.com/jmagar/dendrite",
  "homepage": "https://github.com/jmagar/dendrite",
  "license": "MIT",
  "keywords": ["skills", "vendored", "upstream", "sync"],
  "skills": "./skills/",
  "interface": {
    "displayName": "Upstream Skills",
    "shortDescription": "Skills vendored from upstream repos, kept in sync.",
    "longDescription": "A bundle of agent skills vendored verbatim from their upstream repositories (openclaw and openai orgs). Each skill folder is mirrored whole; the sync-upstream-skills tool detects and applies upstream drift via per-skill content hashes.",
    "developerName": "Jacob Magar",
    "category": "Developer Tools",
    "capabilities": ["Read", "Write", "Automation"],
    "defaultPrompt": [
      "Use the meme-maker skill to caption an image.",
      "Use the handoff skill to summarize this session."
    ],
    "brandColor": "#29B6F6"
  }
}
```

- [ ] **Step 3: Author README and CHANGELOG**

Create `plugins/upstream-skills/README.md`:

```markdown
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
```

Create `plugins/upstream-skills/CHANGELOG.md`:

```markdown
# Changelog

## 0.1.0

- Initial vendoring of upstream skills: gog, acpx, meme-maker, agent-transcript,
  autoreview, handoff, session-viewer, openai-docs, define-goal, chatgpt-apps,
  and yeet.
- Added the sync-upstream-skills tool and upstream-sources manifest.
```

- [ ] **Step 4: Vendor all 11 skills**

Run each command (requires authenticated `gh`):

```bash
plugins/scripts/sync-upstream-skills add https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md
plugins/scripts/sync-upstream-skills add https://github.com/openclaw/acpx/blob/main/skills/acpx/SKILL.md
plugins/scripts/sync-upstream-skills add https://github.com/openclaw/openclaw/tree/main/skills/meme-maker
plugins/scripts/sync-upstream-skills add https://github.com/openclaw/agent-skills/tree/main/skills/agent-transcript
plugins/scripts/sync-upstream-skills add https://github.com/openclaw/agent-skills/tree/main/skills/autoreview
plugins/scripts/sync-upstream-skills add https://github.com/openclaw/agent-skills/tree/main/skills/handoff
plugins/scripts/sync-upstream-skills add https://github.com/openclaw/agent-skills/tree/main/skills/session-viewer
plugins/scripts/sync-upstream-skills add https://github.com/openai/skills/tree/main/skills/.curated/openai-docs
plugins/scripts/sync-upstream-skills add https://github.com/openai/skills/tree/main/skills/.curated/define-goal
plugins/scripts/sync-upstream-skills add https://github.com/openai/skills/tree/main/skills/.curated/chatgpt-apps
plugins/scripts/sync-upstream-skills add https://github.com/openai/skills/tree/main/skills/.curated/yeet
```

Verify: `ls plugins/upstream-skills/skills/` lists all 11; each has `SKILL.md` and `agents/openai.yaml`.
Run: `plugins/scripts/validate-plugin-schemas`
Expected: `Plugin schema validation passed` (manifest now exists and validates).

- [ ] **Step 5: Review/tune the generated openai.yaml stubs**

For each of the 11 `plugins/upstream-skills/skills/<name>/agents/openai.yaml`, read it and confirm `display_name`/`short_description`/`default_prompt` read sensibly. Hand-edit any awkward ones — they are `local_only` and survive future applies. (No code change required if they read well.)

- [ ] **Step 6: Add the marketplace entries**

In `.claude-plugin/marketplace.json`, add to the `plugins` array:

```json
{
  "name": "upstream-skills",
  "source": "./plugins/upstream-skills",
  "description": "Skills vendored verbatim from upstream repos (openclaw + openai), kept in sync via sync-upstream-skills."
}
```

In `.agents/plugins/marketplace.json`, add to the `plugins` array:

```json
{
  "name": "upstream-skills",
  "description": "Skills vendored verbatim from upstream repos (openclaw + openai), kept in sync via sync-upstream-skills.",
  "source": {
    "source": "local",
    "path": "./plugins/upstream-skills"
  },
  "policy": {
    "installation": "AVAILABLE",
    "authentication": "ON_USE"
  },
  "category": "Developer Tools",
  "interface": {
    "displayName": "Upstream Skills",
    "shortDescription": "Skills vendored from upstream repos, kept in sync.",
    "longDescription": "A bundle of agent skills vendored verbatim from their upstream repositories (openclaw and openai orgs). Each skill folder is mirrored whole; the sync-upstream-skills tool detects and applies upstream drift via per-skill content hashes.",
    "developerName": "Jacob Magar",
    "category": "Developer Tools",
    "capabilities": ["Read", "Write", "Automation"],
    "defaultPrompt": [
      "Use the meme-maker skill to caption an image.",
      "Use the handoff skill to summarize this session."
    ],
    "brandColor": "#29B6F6"
  }
}
```

Verify both parse: `jq empty .claude-plugin/marketplace.json .agents/plugins/marketplace.json`

- [ ] **Step 7: Generate gemini extension, README inventory, and docs**

```bash
plugins/scripts/generate-gemini-extensions
plugins/scripts/generate-readme-inventory
plugins/scripts/generate-docs
```

Verify `plugins/upstream-skills/gemini-extension.json` now exists.

- [ ] **Step 8: Run the full check suite**

Run: `plugins/scripts/check-all`
Expected: every check prints its pass line and the script exits 0.

If `check-no-mcp-drift` fails: because `upstream-skills` carries no MCP server, the no-MCP transform is identity for it. Run `plugins/scripts/apply-no-mcp-marketplace` then re-run `plugins/scripts/check-all`; if drift persists it is release-maintenance for the `marketplace-no-mcp` branch (see CLAUDE.md) and out of scope for this plan — note it and proceed.

- [ ] **Step 9: Commit**

```bash
git add plugins/upstream-skills .claude-plugin/marketplace.json .agents/plugins/marketplace.json README.md docs
git commit -m "feat(upstream-skills): vendor 11 upstream skills as a marketplace plugin"
```

(The `README.md` and `docs` paths cover regenerated inventory/matrices. Adjust the `git add` set to whatever `generate-*` actually changed, shown by `git status`.)

---

## Self-Review

**Spec coverage:**
- One new plugin `plugins/upstream-skills/` — Task 10. ✓
- Verbatim folders + local `agents/openai.yaml` preserved — Tasks 3, 5 (preserve/regen), 10. ✓
- Manifest with repo/branch/src_path/pinned_sha/content_hash/local_only — Tasks 4, 6. ✓
- Data contract schema + validate-plugin-schemas wiring — Task 4. ✓
- Behavioral contract (URL parse, hash determinism, add, check, apply) — Tasks 1, 2, 3, 5, 6, 7, 8 tests. ✓
- URL-only onboarding incl. `.curated` dot-segments — Task 1 test `test_dot_prefixed_parent_segment`, Task 10 add commands. ✓
- `check` two drift kinds + exit codes — Task 7, Task 8. ✓
- `apply` propagates deletions, preserves openai.yaml, updates manifest, never commits — Task 5, Task 8. ✓
- Content hash covers references/scripts/added/deleted — Task 2 tests. ✓
- All 11 skills across 5 repos — Task 10 Step 4. ✓
- gemini-extension.json generated not hand-written — Task 10 Step 7. ✓
- One-time scaffolding (manifests, README, CHANGELOG, marketplace entries) — Task 10. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code; no "add error handling" hand-waves. ✓

**Type consistency:** `parse_skill_url` returns `{name, repo, branch, src_path}` used consistently by `add_skill`. `compute_content_hash(dir, local_only) -> "sha256:.."` used by `apply_skill`/`check_skill`. `apply_skill(entry)` mutates `entry` in place; `add_skill` and `_cmd_apply` rely on that. `check_skill(entry) -> list[str]` consumed by `_cmd_check`. The network seam `_download_tarball` is the only thing tests monkeypatch for `fetch_subtree`; `resolve_tip_sha`/`fetch_subtree` are monkeypatched for higher-level tests. ✓
