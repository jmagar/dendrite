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


if __name__ == "__main__":
    unittest.main()
